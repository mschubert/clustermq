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
Q_rows = function(df, fun, const=list(), export=list(), pkgs=c(), seed=128965,
        memory=NULL, template=list(), n_jobs=NULL, job_size=NULL,
        rettype="list", fail_on_error=TRUE, workers=NULL, log_worker=FALSE,
        chunk_size=NA, timeout=Inf, max_calls_worker=Inf, verbose=TRUE) {

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

    # set up workers if none provided
    if (is.null(workers)) {
        qsys_id = toupper(getOption("clustermq.scheduler", qsys_default))
        if (!is.null(n_jobs) && n_jobs == 0)
            qsys_id = "LOCAL"
        if (qsys_id != "LOCAL" && is.null(n_jobs) && is.null(job_size))
            stop("n_jobs or job_size is required")
        n_jobs = Reduce(min, c(ceiling(n_calls / job_size), n_jobs, n_calls))
    } else {
        qsys_id = class(workers$workers)[1]
        n_jobs = Inf #todo: number of workers
    }
    if (qsys_id != "LOCAL" && n_calls > n_jobs*max_calls_worker)
        stop("n_jobs and max_calls_worker provide fewer call slots than required")
    if (is.null(workers))
        workers = workers(n_jobs, reuse=FALSE, template=template,
                          log_worker=log_worker, verbose=verbose)
    workers$env(fun=fun, rettype=rettype, common_seed=seed, const=const)
    workers$pkg(pkgs)
    do.call(workers$env, export)

    # heuristic for chunk size
    if (is.na(chunk_size))
        chunk_size = round(Reduce(min, c(
            500,                    # never more than 500
            n_calls / n_jobs / 100, # each worker reports back 100 times
            n_calls / 2000,         # at most 2000 reports total
            1e4 * n_calls / utils::object.size(df)[[1]] # no more than 10 kb
        )))
    chunk_size = max(chunk_size, 1)

    # process calls
    if (inherits(workers$workers, "LOCAL")) {
        list2env(export, envir=environment(fun))
        for (pkg in pkgs) # is it possible to attach the package to fun's env?
            library(pkg, character.only=TRUE)
        re = work_chunk(df=df, fun=fun, const=const, rettype=rettype,
                        common_seed=seed, progress=TRUE)
        summarize_result(re$result, length(re$errors), length(re$warnings),
                         re[c("errors", "warnings")], fail_on_error=fail_on_error)
    } else {
        master(pool=workers, iter=df, rettype=rettype,
               fail_on_error=fail_on_error, chunk_size=chunk_size,
               timeout=timeout, max_calls_worker=max_calls_worker,
               verbose=verbose)
    }
}
