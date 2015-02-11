# BatchJobsWrapper.r
#
# Rationale
#  This script uses BatchJobs to run functions either locally, on multiple cores, or LSF,
#  depending on your BatchJobs configuration. It has a simpler interface, does more error
#  checking than the library itself, and is able to queue different function calls. The
#  function supplied *MUST* be self-sufficient, i.e. load libraries and scripts.
#  BatchJobs on the EBI cluster is already set up when using the gentoo prefix.
#
# Usage
#  * Q()     : create a new registry with that vectorises a function call and optionally runs it
#  * Qrun()  : run all registries in the current working directory
#  * Qget()  : extract the results from the registry and returns them
#  * Qclean(): delete all registries in the current working directory
#  * Qregs() : list all registries in the current working directory
#
# Examples
#  > s = function(x) x
#  > Q(s, x=c(1:3), get=T)
#  returns list(1,2,3)
#
#  > t = function(x) sum(x)
#  > a = matrix(3:6, nrow=2)
#  > Q(t, a)
#  > Qget()
#  splits a by columns, sums each column, and returns list(7, 11)
#
# TODO list
#  * handle failed jobs? (e.g.: save layout to registry dir to rerun failed jobs) [rerun option?]

library(stringr)
library(BatchJobs)
library(dplyr)
.b = import('../base')

#' Registry object the module is working on
.Qreg = NULL

#' Submit function calls as cluster jobs
#'
#' This function takes the function \code{` fun`} and calls it with each element of the iterable
#' \code{...}, either in order or as grid. Depending on how \emph{BatchJobs} is set up, these
#' function calls are processed either sequentially, on multicore, or as LSF/SGE/etc. jobs.
#'
#' For normal usage, this is the only function necessary to call explicitly (set \code{get=T} to
#' get the function results returned).
#'
#' @param ` fun`          the function to call
#' @param ...             arguments to vectorise over
#' @param more.args       arguments not to vectorise over
#' @param export          objects to export to computing nodes
#' @param get             returns the result of the run (default:T)
#' @param memory          how many Mb of memory should be reserved to run the job
#' @param split.array.by  how to split matrices/arrays in \code{...} (default: last dimension)
#' @param expand.grid     do every combination of arguments to vectorise over
#' @param seed            random seed for the function to run
#' @param n.chunks        how much jobs to split functions calls into (default: number of calls)
#' @param chunk.size      how many function calls in one job (default: 1)
#' @param fail.on.error   if jobs fail, return all successful or throw overall error?
#' @return                list of job results if get=T
Q = function(` fun`, ..., more.args=list(), export=list(), get=T, expand.grid=FALSE,
        memory=NULL, n.chunks=NULL, chunk.size=NULL, split.array.by=NA, seed=123, fail.on.error=TRUE) {
    # summarise arguments
    l. = list(...)
    fun = match.fun(` fun`)
    funargs = formals(fun)
    required = names(funargs)[unlist(lapply(funargs, function(f) class(f)=='name'))]
    provided= names(c(l., more.args))

    # perform checks that BatchJobs doesn't do
    if ('reg' %in% provided || 'fun' %in% provided)
        stop("'reg' and 'fun' are reserved and thus not allowed as argument to ` fun`")
    if (any(grepl("^ ", provided)))
        stop("Arguments starting with space are not allowed")
    if (expand.grid && length(l.) == 1)
        stop("Can not expand.grid on one vector")

    if (length(provided) > 1) {
        if (sum(nchar(provided) == 0) > 1) #TODO: check if potential issues
            stop("At most one arugment can be unnamed in the function call")

        sdiff = unlist(setdiff(required, provided))
        if (length(sdiff) > 0 && sdiff != '...')
            stop(paste("Argument required but not provided:", paste(sdiff, collapse=" ")))
    }

    sdiff = unlist(setdiff(provided, names(funargs)))
    if (length(sdiff) > 0 && ! '...' %in% names(funargs))
        stop(paste("Argument provided but not accepted by function:", paste(sdiff, collapse=" ")))
    dups = duplicated(provided)
    if (any(dups))
        stop(paste("Argument duplicated:", paste(provided[[dups]], collapse=" ")))

    # convert matrices to lists so they can be vectorised over
    split_mat = function(X) { #TODO: move this to array (with: -1=last dim)
        if (is.array(X) && length(dim(X)) > 1) {
            if (is.na(split.array.by))
                setNames(plyr::alply(X, length(dim(X))), dimnames(X)[[length(dim(X))]])
            else
                setNames(plyr::alply(X, split.array.by), dimnames(X)[[split.array.by]])
        } else
            X
    }
    l. = lapply(l., split_mat)

    tmpdir = tempdir()
    reg = makeRegistry(id=basename(tmpdir), file.dir=tmpdir, seed=seed)

    # export objects to nodes if desired
    if (length(export) > 0)
        do.call(batchExport, c(list(reg=reg), export))

    # fill the registry with function calls, save names as well
    if (expand.grid) { #TODO: name columns in layout df properly (formals if no names)
        layout = expand.grid(lapply(l., .b$descriptive_index))
        do.call(batchExpandGrid, c(list(reg=reg, fun=fun, more.args=more.args), l.))
    } else {
        layout = as.data.frame(lapply(l., .b$descriptive_index))
        do.call(batchMap, c(list(reg=reg, fun=fun, more.args=more.args), l.))
    }

    assign('Qreg', reg, envir=parent.env(environment()))

    Qrun(n.chunks=n.chunks, chunk.size=chunk.size, memory=memory)
    
    if (get) {
        layout$result = setNames(rep(list(NA),nrow(layout)), 1:nrow(layout))
        result = Qget(fail.on.error=fail.on.error)
        layout$result[names(result)] = result
    }
    layout
}

#' Run all registries if \code{run=F} in \code{Q()}
#'
#' @param n.chunks    number of chunks (cores, LSF jobs) to split each registry into
#' @param chunk.size  number of calls to put into one core/LSF job (do not use with n.chunks)
#' @param memory      how many Mb of memory should be reserved to run the job
#' @param shuffle     if chunking, shuffle the order of calls
Qrun = function(n.chunks=NULL, chunk.size=NULL, memory=NULL, shuffle=T) {
    if (!is.null(n.chunks) && !is.null(chunk.size))
        stop("Can not take both n.chunks and chunk.size")

    reg = get('Qreg', envir=parent.env(environment()))

    ids = getJobIds(reg)
    if (!is.null(n.chunks))
        ids = chunk(ids, n.chunks=n.chunks, shuffle=shuffle)
    if (!is.null(chunk.size))
        ids = chunk(ids, chunk.size=chunk.size, shuffle=shuffle)

    if (is.null(memory))
        submitJobs(reg, ids, chunks.as.arrayjobs=F, job.delay=T, max.retries=Inf)
    else
        submitJobs(reg, ids, chunks.as.arrayjobs=F, job.delay=T, max.retries=Inf,
                   resources=list(memory=memory))
}

#' Get all results if \code{get=F} in \code{Q()}
#'
#' @param clean           delete the registry when done
#' @param fail.on.errors  whether to get only successful results or throw overall error
#' @return                a list of results of the function called with different arguments
Qget = function(clean=TRUE, fail.on.error=TRUE) {
    reg = get('Qreg', envir=parent.env(environment()))

    waitForJobs(reg, ids=getJobIds(reg))
    print(showStatus(reg, errors=100L))
    if (fail.on.error)
        result = reduceResultsList(reg, ids=getJobIds(reg), fun=function(job, res) res)
    else
        result = reduceResultsList(reg, fun=function(job, res) res)

    if (clean)
        Qclean()

    result
}

#' Delete the registry the module is working on
Qclean = function() {
    reg = get('Qreg', envir=parent.env(environment()))
    unlink(reg$file.dir, recursive=T)
}
