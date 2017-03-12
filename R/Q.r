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

    iter = list(...)
    fun = match.fun(fun)
    Q_check(fun, iter, const)

    # check job number and memory
    if (qsys_id != "LOCAL" && is.null(n_jobs) && is.null(job_size))
        stop("n_jobs or job_size is required")
    if (memory < 500)
        stop("Worker needs about 230 MB overhead, set memory>=500")

    # create call index
    call_index = Q_call_index(iter, expand_grid, split_array_by)
    n_calls = nrow(call_index)
    n_jobs = Reduce(min, c(ceiling(n_calls / job_size), n_jobs, n_calls))

    # use heuristic for wait and chunk size
    if (is.na(wait_time))
        wait_time = ifelse(n_calls < 5e5, 1/sqrt(n_calls), 0)
    if (is.na(chunk_size))
        chunk_size = ceiling(min(
            n_calls / n_jobs / 100,
            1e4 * n_calls / utils::object.size(call_index)[[1]]
        ))

    if (n_jobs == 0 || qsys_id == "LOCAL")
        work_chunk(df=call_index, fun=fun, const_args=const, common_seed=seed)
    else
        master(fun=fun, iter=call_index, const=const,
               seed=seed, memory=memory, n_jobs=n_jobs,
               fail_on_error=fail_on_error, log_worker=log_worker,
               wait_time=wait_time, chunk_size=chunk_size)
}
