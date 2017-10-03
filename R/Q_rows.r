#' Queue function calls defined by rows in a data.frame
#'
#' @param df  data.frame with iterated arguments
#' @inheritParams Q
#' @export
Q_rows = function(df, fun, const=list(), export=list(), seed=128965,
        memory=NULL, template=list(), n_jobs=NULL, job_size=NULL,
        fail_on_error=TRUE, workers=NULL,
        log_worker=FALSE, wait_time=NA, chunk_size=NA) {

    # basic variable checking
    fun = match.fun(fun)
    df = as.data.frame(df, check.names=FALSE, stringsAsFactors=FALSE)
    n_calls = nrow(df)
    n_jobs = Reduce(min, c(ceiling(n_calls / job_size), n_jobs, n_calls))
    seed = as.integer(seed)
    check_args(fun, df, const)

    if (!is.null(workers)) {
        qsys_id = class(workers)[1]
        n_jobs = workers$workers
        job_size = NULL
    } else
        qsys_id = toupper(qsys_default)

    # check job number and memory
    if (qsys_id != "LOCAL" && is.null(n_jobs) && is.null(job_size))
        stop("n_jobs or job_size is required")
    if (!is.null(memory))
        template$memory = memory
    if (!is.null(template$memory) && template$memory < 500)
        stop("Worker needs about 230 MB overhead, set memory>=500")
    if (is.na(seed) || length(seed) != 1)
        stop("'seed' needs to be a length-1 integer")

    # use heuristic for wait and chunk size
    if (is.na(wait_time))
        wait_time = min(0.03, ifelse(n_calls < 1e5, 1/sqrt(n_calls), 0))
    if (is.na(chunk_size))
        chunk_size = ceiling(min(
            n_calls / 2000,
            1e4 * n_calls / utils::object.size(df)[[1]]
        ))

    if (n_jobs == 0 || qsys_id == "LOCAL") {
        list2env(export, envir=environment(fun))
        re = work_chunk(df=df, fun=fun, const_args=const, common_seed=seed)
        unravel_result(re, fail_on_error=fail_on_error)
    } else {
        data = list(fun=fun, const=const, export=export, common_seed=seed)

        if (is.null(workers)) {
            qsys = workers(n_jobs, data=data, reuse=FALSE, template=template,
                           log_worker=log_worker)
            on.exit(qsys$cleanup())
        } else {
            qsys = workers
            do.call(qsys$set_common_data, data)
        }

        master(qsys=qsys, iter=df, fail_on_error=fail_on_error,
               wait_time=wait_time, chunk_size=chunk_size)
    }
}
