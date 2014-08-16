#' BatchJobsWrapper.r
#'
#' Rationale
#'  This script uses BatchJobs to run functions either locally, on multiple cores, or LSF,
#'  depending on your BatchJobs configuration. It has a simpler interface, does more error
#'  checking than the library itself, and is able to queue different function calls. The
#'  function supplied *MUST* be self-sufficient, i.e. load libraries and scripts.
#'  BatchJobs on the EBI cluster is already set up when using the gentoo prefix.
#'
#' Usage
#'  * Q()     : create a new registry with that vectorises a function call and optionally runs it
#'  * Qrun()  : run all registries in the current working directory
#'  * Qget()  : extract the results from the registry and returns them
#'  * Qclean(): delete all registries in the current working directory
#'  * Qregs() : list all registries in the current working directory
#'
#' Examples
#'  > s = function(x) x
#'  > Q(s, x=c(1:3), get=T)
#'  returns list(1,2,3)
#'
#'  > t = function(x) sum(x)
#'  > a = matrix(3:6, nrow=2)
#'  > Q(t, a)
#'  > Qget()
#'  splits a by columns, sums each column, and returns list(7, 11)
#'
#' TODO list
#'  * handle failed jobs? (e.g.: save layout to registry dir to rerun failed jobs) [rerun option?]
#'  * Qget(): warn when not all jobs are returned
#'  * Qregs(): possible that creation time does not follow call time?

library(stringr)
library(BatchJobs)
library(plyr)
library(modules)

.QLocalRegistries = list()

#' Creates a new registry with that vectorises a function call and optionally runs it
#'  ` fun`        : the function to call
#'  ...           : arguments to vectorise over
#'  more.args     : arguments not to vectorise over
#'  export        : objects to export to computing nodes
#'  name          : the name of the function call if more than one are submitted
#'  run           : execute the function, don't just queue
#'  get           : returns the result of the run; implies run=T
#'  split.array.by: how to split matrices/arrays in ... (default: last dimension)
#'  expand.grid   : do every combination of arguments to vectorise over
#'  grid.sep      : separator to use when assembling names from expand.grid
#'  seed          : random seed for the function to run
#'  @return       : list of job results if get=T
Q = function(` fun`, ..., more.args=list(), export=list(), name=NULL, 
             run=T, get=F, n.chunks=NULL, chunk.size=NULL, split.array.by=NA, 
             expand.grid=F, grid.sep=":", seed=123, fail.on.error=T,
             set.names=fail.on.error) {
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
        if (any(nchar(provided) == 0))
            stop("All arguments that will be provided to function must be named")

        sdiff = unlist(setdiff(required, provided))
        if (length(sdiff) > 0 && sdiff != '...')
            stop(paste("Argument required but not provided:", paste(sdiff, collapse=" ")))
    }

    sdiff = unlist(setdiff(provided, names(funargs)))
    if (length(sdiff) > 0 && ! '...' %in% names(funargs))
        stop(paste("Argument provided by not accepted by function:", paste(sdiff, collapse=" ")))
    dups = duplicated(provided)
    if (any(dups))
        stop(paste("Argument duplicated:", paste(provided[[dups]], collapse=" ")))

    # convert matrices to lists so they can be vectorised over
    split_mat = function(X) {
        if (is.array(X) && length(dim(X)) > 1) {
            if (is.na(split.array.by))
                setNames(alply(X, length(dim(X))), dimnames(X)[[length(dim(X))]])
            else
                setNames(alply(X, split.array.by), dimnames(X)[[split.array.by]])
        } else
            X
    }
    l. = lapply(l., split_mat)

    # name every vector so we can identify them afterwards
    ln = lapply(l., names)
    lnFull = lapply(1:length(ln), function(i)
        if (is.character(l.[[i]]) && length(l.[[i]][1])==1 && is.null(ln[[i]]))
            l.[[i]]
        else if (is.null(ln[[i]]))
            1:length(l.[[i]])
        else
            ln[[i]]
    )
 
    tmpdir = tempdir()
    reg = makeRegistry(id=basename(tmpdir), file.dir=tmpdir, seed=seed)

    # export objects to nodes if desired
    if (length(export) > 0)
        do.call(batchExport, c(list(reg), export))

    # fill the registry with function calls, save names as well
    if (expand.grid)
        do.call(batchExpandGrid, c(list(reg=reg, fun=fun, more.args=more.args), l.))
    else
        do.call(batchMap, c(list(reg=reg, fun=fun, more.args=more.args), l.))

    if (expand.grid || is.null(unlist(ln)))
        resultNames = apply(expand.grid(lnFull), 1, function(x) paste(x,collapse=grid.sep))
    else
        resultNames = as.matrix(apply(do.call(cbind, ln), 1, unique))
    save(resultNames, name, set.names, file=file.path(tmpdir, "names.RData"))

    assign('.QLocalRegistries', c(.QLocalRegistries, setNames(list(reg), name)), 
           envir=parent.env(environment()))

    if (run)
        Qrun(regs=reg, n.chunks=n.chunks, chunk.size=chunk.size)
    if (get)
        Qget(regs=reg, fail.on.error=fail.on.error)[[1]]
}

#' Runs all registries in the current working directory
#'  n.chunks  : number of chunks (cores, LSF jobs) to split each registry into
#'  chunk.size: number of calls to put into one core/LSF job (do not use with n.chunks)
#'  shuffle   : if chunking, shuffle the order of calls
#'  regs      : list of registries to include; default: all local
Qrun = function(n.chunks=NULL, chunk.size=NULL, shuffle=T, regs=Qregs()) {
    if (!is.null(n.chunks) && !is.null(chunk.size))
        stop("Can not take both n.chunks and chunk.size")

    if (class(regs) == 'Registry')
        regs = list(regs)

    for (reg in regs) {
        ids = getJobIds(reg)
        if (!is.null(n.chunks))
            ids = chunk(ids, n.chunks=n.chunks, shuffle=shuffle)
        if (!is.null(chunk.size))
            ids = chunk(ids, chunk.size=chunk.size, shuffle=shuffle)
        submitJobs(reg, ids, chunks.as.arrayjobs=F, job.delay=T)
    }
}

#' Extracts the results from the registry and returns them
#'  clean  : delete the registry when done
#'  regs   : list of registries to include; default: all local
#'  @return: a list of results of the function called with different arguments
Qget = function(clean=T, regs=Qregs(), fail.on.error=T) {
    if (class(regs) == 'Registry')
        regs = list(regs)

    getResult = function(reg) {
        waitForJobs(reg, ids=getJobIds(reg))
        print(showStatus(reg, errors=100L))
        if (fail.on.error)
            result = reduceResultsList(reg, ids=getJobIds(reg),
                                       fun=function(job, res) res)
        else
            result = reduceResultsList(reg, fun=function(job, res) res)
        load(file.path(reg$file.dir, 'names.RData')) # resultNames
        if (clean)
            Qclean(reg)
        if (set.names)
            setNames(result, resultNames[as.integer(names(result))])
        else
            result
    }

    setNames(lapply(regs, getResult), names(regs))
}

#' Deletes all registries in the current working directory
#'  regs: list of registries to include; default: all local
Qclean = function(regs=Qregs()) {
    if (class(regs) == 'Registry')
        regs = list(regs)

    for (reg in regs)
        unlink(reg$file.dir, recursive=T)
}

#' Lists all registries in the current working directory
#'  name     : regular expression specifying the registry name
#'  directory: regular expression specifying the directories to look for registries
#'  local    : only return registries created in this R session
#'  @return  : a list of registry objects
Qregs = function(name=".*", directory="Rtmp[0-9a-zA-Z]+", local=T) {
    if (local)
        return(.QLocalRegistries)
    
    regdirs = list.files(pattern=directory, include.dirs=T)
    if (length(regdirs) == 0) return(list())
    regfun = function(path) list.files(path=path, pattern="^registry.RData$", full.names=T)
    details = file.info(sapply(regdirs, regfun))
    regfiles = rownames(details[with(details, order(as.POSIXct(mtime))),])
    
    getRegistry = function(rdir) {
        load(file.path(rdir, 'registry.RData'))
        load(file.path(rdir, 'names.RData'))
        list(name, reg)
    }
    regs = lapply(regdirs, getRegistry)
    regs = setNames(lapply(regs, function(x) x[[2]]), sapply(regs, function(x) x[[1]]))
    regs[grepl(name, names(regs))]
}   

