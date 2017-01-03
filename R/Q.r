#' Queue function calls on the cluster
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
#' @param split_array_by  The dimension number to split any arrays in `...`; default: last
#' @param fail_on_error   If an error occurs on the workers, continue or fail?
#' @param log_worker      Write a log file for each worker
#' @param wait_time       Time to wait between messages; set 0 for short calls
#'                        defaults to 1/sqrt(number_of_functon_calls)
#' @param chunk_size      Number of function calls to chunk together
#'                        defaults to 100 chunks per worker or max. 10 kb per chunk
#' @return                A list of whatever `fun` returned
#' @export
Q = function(fun, ..., const=list(), expand_grid=FALSE, seed=128965,
        memory=4096, n_jobs=NULL, job_size=NULL, split_array_by=NA, fail_on_error=TRUE,
        log_worker=FALSE, wait_time=NA, chunk_size=NA) {

    if (is.null(n_jobs) && is.null(job_size))
        stop("n_jobs or job_size is required")
    if (memory < 500)
        stop("Worker needs about 230 MB overhead, set memory>=500")

    # check function and arguments provided
    iter = list(...)
    fun = match.fun(fun)
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

    # convert matrices to lists so they can be vectorised over
    split_arrays = function(x) {
        if (is.array(x))
            narray::split(x, along=ifelse(is.na(split_array_by), -1, split_array_by))
        else
            x
    }
    iter_split = lapply(iter, split_arrays)

    if (expand_grid)
        iter_split = do.call(expand.grid, c(iter_split,
                list(KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)))

    # prepare data and other args
    job_data = as.data.frame(do.call(tibble::data_frame, iter_split))
    n_calls = nrow(job_data)
    n_jobs = min(ceiling(n_calls / job_size), n_jobs)

    # if for whatever reason the query data is empty
    if (n_calls == 0) {
        warning("No input data for function calls, returning empty result")
        return(list())
    }

    # use heuristic for wait and chunk size
    if (is.na(wait_time))
        wait_time = ifelse(n_calls < 5e5, 1/sqrt(n_calls), 0)
    if (is.na(chunk_size))
        chunk_size = ceiling(min(
            n_calls / n_jobs / 100,
            1e4 * n_calls / object.size(job_data)[[1]]
        ))

    master(fun=fun, iter=job_data, const=const,
           seed=seed, memory=memory, n_jobs=n_jobs,
           fail_on_error=fail_on_error, log_worker=log_worker,
           wait_time=wait_time, chunk_size=chunk_size)
}
