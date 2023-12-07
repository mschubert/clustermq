#' Queue function calls on the cluster
#'
#' @param fun             A function to call
#' @param ...             Objects to be iterated in each function call
#' @param const           A list of constant arguments passed to each function call
#' @param export          List of objects to be exported to the worker
#' @param pkgs            Character vector of packages to load on the worker
#' @param seed            A seed to set for each function call
#' @param memory          Short for template=list(memory=value)
#' @param template        A named list of values to fill in template
#' @param n_jobs          The number of LSF jobs to submit; upper limit of jobs
#'                        if job_size is given as well
#' @param job_size        The number of function calls per job
#' @param split_array_by  The dimension number to split any arrays in `...`; default: last
#' @param rettype         Return type of function call (vector type or 'list')
#' @param fail_on_error   If an error occurs on the workers, continue or fail?
#' @param workers         Optional instance of QSys representing a worker pool
#' @param log_worker      Write a log file for each worker
#' @param chunk_size      Number of function calls to chunk together
#'                        defaults to 100 chunks per worker or max. 10 kb per chunk
#' @param timeout         Maximum time in seconds to wait for worker (default: Inf)
#' @param max_calls_worker  Maxmimum number of chunks that will be sent to one worker
#' @param verbose         Print status messages and progress bar (default: TRUE)
#' @return                A list of whatever `fun` returned
#' @export
#'
#' @examples
#' \dontrun{
#' # Run a simple multiplication for numbers 1 to 3 on a worker node
#' fx = function(x) x * 2
#' Q(fx, x=1:3, n_jobs=1)
#' # list(2,4,6)
#'
#' # Run a mutate() call in dplyr on a worker node
#' iris %>%
#'     mutate(area = Q(`*`, e1=Sepal.Length, e2=Sepal.Width, n_jobs=1))
#' # iris with an additional column 'area'
#' }
Q = function(fun, ..., const=list(), export=list(), pkgs=c(), seed=128965,
        memory=NULL, template=list(), n_jobs=NULL, job_size=NULL,
        split_array_by=-1, rettype="list", fail_on_error=TRUE, workers=NULL,
        log_worker=FALSE, chunk_size=NA, timeout=Inf, max_calls_worker=Inf,
        verbose=TRUE) {

    split_arrays = function(x) {
        if (is.array(x)) {
            .Deprecated("narray package directly")
            narray::split(x, along=split_array_by)
        } else
            x
    }
    iter = lapply(list(...), split_arrays)
    df = check_args(fun, iter, const)

    Q_rows(fun = fun,
           df = df,
           const = const,
           export = export,
           pkgs = pkgs,
           seed = seed,
           memory = memory,
           template = template,
           n_jobs = n_jobs,
           job_size = job_size,
           rettype = rettype,
           fail_on_error = fail_on_error,
           workers = workers,
           log_worker = log_worker,
           chunk_size = chunk_size,
           timeout = timeout,
           max_calls_worker = max_calls_worker,
           verbose = verbose)
}
