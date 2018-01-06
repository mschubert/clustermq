#' Queue function calls defined by rows in a data.frame
#'
#' @param df  data.frame with iterated arguments
#' @inheritParams Q
#' @export
Q_rows = function(df, fun, const=list(), export=list(), seed=128965,
        memory=NULL, template=list(), n_jobs=NULL, job_size=NULL,
        rettype="list", fail_on_error=TRUE, workers=NULL,
        log_worker=FALSE, wait_time=NA, chunk_size=NA) {

    # check if call args make sense
    if (!is.null(memory))
        template$memory = memory
    if (!is.null(template$memory) && template$memory < 50)
        stop("Worker needs about 23 MB overhead, set memory>=50")
    if (is.na(seed) || length(seed) != 1)
        stop("'seed' needs to be a length-1 integer")

    fun = match.fun(fun)
    df = as.data.frame(df, check.names=FALSE, stringsAsFactors=FALSE)
    n_calls = nrow(df)
    seed = as.integer(seed)
    check_args(fun, df, const)
    data = list(fun=fun, const=const, export=export,
                rettype=rettype, common_seed=seed)

    # set up qsys if no workers provided
    if (is.null(workers)) {
        qsys_id = toupper(qsys_default)
        if (qsys_id != "LOCAL" && is.null(n_jobs) && is.null(job_size))
            stop("n_jobs or job_size is required")
        n_jobs = Reduce(min, c(ceiling(n_calls / job_size), n_jobs, n_calls))

        qsys = workers(n_jobs, data=data, reuse=FALSE, template=template,
                       log_worker=log_worker)
    } else {
        qsys_id = class(workers)[1]
        n_jobs = workers$workers
        job_size = NULL
        qsys = workers
        do.call(qsys$set_common_data, data)
    }

    if (!qsys$reusable)
        on.exit(qsys$cleanup())

    # use heuristic for wait and chunk size
    if (is.na(wait_time))
        wait_time = min(0.03, ifelse(n_calls < 1e5, 1/sqrt(n_calls), 0))
    if (is.na(chunk_size))
        chunk_size = ceiling(min(
            n_calls / 2000,
            1e4 * n_calls / utils::object.size(df)[[1]]
        ))

    # process calls
    if (n_jobs == 0 || qsys_id == "LOCAL") {
        list2env(export, envir=environment(fun))
        re = work_chunk(df=df, fun=fun, const_args=const, rettype=rettype,
                        common_seed=seed)
        summarize_result(re$result, length(re$errors), length(re$warnings),
                         c(re$errors, re$warnings), fail_on_error=fail_on_error)
    } else {
        master(qsys=qsys, iter=df, rettype=rettype, fail_on_error=fail_on_error,
               wait_time=wait_time, chunk_size=chunk_size)
    }
}
