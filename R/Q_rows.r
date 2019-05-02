#' Queue function calls defined by rows in a data.frame
#'
#' @param df  data.frame with iterated arguments
#' @inheritParams Q
#' @export
#'
#' @examples
#' \dontrun{
#' # Run a simple multiplication for data frame columns x and y on a worker node
#' fx = function (x, y) x * y
#' df = data.frame(x = 5, y = 10)
#' Q_rows(df, fx, job_size = 1)
#' # [1] 50
#'
#' # Q_rows also matches the names of a data frame with the function arguments
#' fx = function (x, y) x - y
#' df = data.frame(y = 5, x = 10)
#' Q_rows(df, fx, job_size = 1)
#' # [1] 5
#' }
Q_rows = function(df, fun, const=list(), export=list(), seed=128965,
        memory=NULL, template=list(), n_jobs=NULL, job_size=NULL,
        rettype="list", fail_on_error=TRUE, workers=NULL,
        log_worker=FALSE, chunk_size=NA, timeout=Inf, max_calls_worker=Inf) {

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

    # set up workers if none provided
    if (is.null(workers)) {
        qsys_id = toupper(getOption("clustermq.scheduler", qsys_default))
        if (qsys_id != "LOCAL" && is.null(n_jobs) && is.null(job_size))
            stop("n_jobs or job_size is required")
        n_jobs = Reduce(min, c(ceiling(n_calls / job_size), n_jobs, n_calls))

        workers = workers(n_jobs, data=data, reuse=FALSE, template=template,
                          log_worker=log_worker)
    } else
        do.call(workers$set_common_data, data)

    # use heuristic for wait and chunk size
    if (is.na(chunk_size))
        chunk_size = ceiling(min(
            n_calls / 2000,
            1e4 * n_calls / utils::object.size(df)[[1]]
        ))

    # process calls
    if (class(workers)[1] == "LOCAL") {
        list2env(export, envir=environment(fun))
        re = work_chunk(df=df, fun=fun, const=const, rettype=rettype,
                        common_seed=seed, progress=TRUE)
        summarize_result(re$result, length(re$errors), length(re$warnings),
                         c(re$errors, re$warnings), fail_on_error=fail_on_error)
    } else {
        if (workers$workers == 0)
            stop("Attempting to use workers object without active workers")
        master(qsys=workers, iter=df, rettype=rettype,
               fail_on_error=fail_on_error, chunk_size=chunk_size,
               timeout=timeout, max_calls_worker=max_calls_worker)
    }
}
