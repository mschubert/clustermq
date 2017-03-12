#' Function to check arguments with which Q() is called
#'
#' @param fun       A function to call
#' @param iter      Objects to be iterated in each function call
#' @param const     A list of constant arguments passed to each function call
Q_check = function(fun, iter, const=list()) {
    if (!is.list(iter) || length(iter) == 0)
        stop("'iter' needs to be a list with at least one element")

    # check function and arguments provided
    funargs = formals(fun)
    required = names(funargs)[unlist(lapply(funargs, function(f) class(f)=='name'))]

    if (length(iter) == 1 && length(required) == 1 && is.null(names(iter)))
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
    if (length(sdiff) > 0 && ! '...' %in% names(funargs))
        stop(paste("Argument provided but not accepted by function:", paste(sdiff, collapse=" ")))

    dups = duplicated(provided)
    if (any(dups))
        stop(paste("Argument duplicated:", paste(provided[[dups]], collapse=" ")))
}
