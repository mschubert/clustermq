#' Function to check arguments with which Q() is called
#'
#' @param fun             A function to call
#' @param ...             Objects to be iterated in each function call
#' @param const           A list of constant arguments passed to each function call
#' @param expand_grid     Use all combinations of arguments in `...`
#' @param seed            A seed to set for each function call
#' @param memory          The amount of Mb to request from LSF; default: 1 Gb
#' @param n_jobs          The number of LSF jobs to submit; upper limit of jobs
#'                        if job_size is given as well
#' @param job_size        The number of function calls per job
Q_check = function(fun, iter, const, n_jobs, job_size, memory) {
    # check function and arguments provided
    funargs = formals(fun)
    required = names(funargs)[unlist(lapply(funargs, function(f) class(f)=='name'))]

    if (length(iter) == 1 && length(required) == 1)
        names(iter) = required

    provided = names(c(iter, const))

    # perform checks that BatchJobs doesn't do
    if ('reg' %in% provided || 'fun' %in% provided)
        stop("'reg' and 'fun' are reserved and thus not allowed as argument to ` fun`")
    if (any(grepl("^ ", provided)))
        stop("Arguments starting with space are not allowed")

    sdiff = unlist(setdiff(required, provided))
    if (length(sdiff) > 1 && sdiff != '...')
        stop(paste("If more than one argument, all must be named:", paste(sdiff, collapse=" ")))

    sdiff = unlist(setdiff(provided, names(funargs)))
#    if (length(sdiff) > 1 && ! '...' %in% names(funargs))
#        stop(paste("Argument provided but not accepted by function:", paste(sdiff, collapse=" ")))
    dups = duplicated(provided)
    if (any(dups))
        stop(paste("Argument duplicated:", paste(provided[[dups]], collapse=" ")))
}
