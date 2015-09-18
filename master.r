# Rationale
#  This script uses rzmq to run function calls as LSF jobs.
#  The function supplied *MUST* be self-sufficient, i.e. load libraries and scripts.
#  BatchJobs on the EBI cluster is already set up when using the gentoo prefix.
#
# Usage
#  * Q()     : create a new registry with that vectorises a function call
#
# Examples
#  > s = function(x) x
#  > Q(s, x=c(1:3))
#  returns list(1,2,3)
#
#  > t = function(x) sum(x)
#  > a = matrix(3:6, nrow=2)
#  > Q(t, a)
#  > Qget()
#  splits a by columns, sums each column, and returns list(7, 11)
#
# TODO list
#  * handle failed jobs? (e.g.: save layout to registry dir to rerun failed jobs) [rerun option?]
.p = import('./process_args')

# Check that all the required packags (master and worker) are installed
.req_pkg = c("rzmq", "infuser", "pryr", "ulimit")
.pkg_missing = setdiff(.req_pkg, rownames(installed.packages()))
if (any(.pkg_missing))
    stop("The following packages need to be installed: ", paste(.pkg_missing, sep=", "))

#' @param fun             A function to call
#' @param ...             Objects to be iterated in each function call
#' @param const           A list of constant arguments passed to each function call
#' @param expand_grid     Use all combinations of arguments in `...`
#' @param seed            A seed to select seeds for each function call
#' @param memory          The amount of Mb to request from LSF; default: 1 Gb
#' @param n_jobs          The number of LSF jobs to submit
#' @param job_size        The number of function calls per job; if n_jobs is given,
#'                        this will have priority
#' @param split_array_by  The dimension number to split any arrays in `...`; default: last
#' @param fail_on_error   If an error occurs on the workers, continue or fail?
#' @param log_worker      Write a log file for each worker
#' @return                A list of whatever `fun` returned
Q = function(fun, ..., const=list(), expand_grid=FALSE, seed=128965, memory=4096, n_jobs=NULL,
             job_size=NULL, split_array_by=NA, fail_on_error=TRUE, log_worker=FALSE) {
    if (is.null(n_jobs) && is.null(job_size))
        stop("n_jobs or job_size is required")
    if (memory < 500)
        stop("Worker needs about 230 MB overhead, set memory>=500")

    worker_file = module_file("worker.r") #BUG: in modules, could do this directly otherwise
    lsf_file = module_file("LSF.tmpl") #BUG: same as above
    infuser = import_package('infuser')
    import_package('rzmq', attach=TRUE)

    fun = match.fun(fun)
    job_data = .p$process_args(fun, iter=list(...), const=const,
                               expand_grid=expand_grid,
                               split_array_by=split_array_by)
    names(job_data) = 1:length(job_data)

    # bind socket
    zmq.context = init.context()
    socket = init.socket(zmq.context, "ZMQ_REP")
    sink('/dev/null')
    for (i in 1:100) {
        exec_socket = sample(6000:8000, size=1)
        port_found = bind.socket(socket, paste0("tcp://*:", exec_socket))
        if (port_found)
            break
    }
    sink()
    if (!port_found)
        stop("Could not bind to a port in range (6000,8000) after 100 tries")

    # use the template & submit
    values = list(
        queue = "research-rh6",
        walltime = 10080,
        memory = memory,
        rscript = worker_file,
        args = sprintf("tcp://%s:%i %i", Sys.info()[['nodename']], exec_socket, memory)
    )

    # do the submissions
    message("Submitting worker jobs ...")
    pb = txtProgressBar(min=0, max=n_jobs, style=3)
    for (j in 1:n_jobs) {
        values$job_name = paste0("rzmq", exec_socket, "-", j)
        if (log_worker)
            values$log_file = paste0(values$job_name, ".log")
        else
            values$log_file = "/dev/null"
        system("bsub", input=infuser$infuse(lsf_file, values), ignore.stdout=TRUE)
        setTxtProgressBar(pb, j)
    }
    close(pb)

    job_result = rep(list(NULL), length(job_data))
    submit_index = 1
    jobs_running = c()

    message("Running calculations ...")
    pb = txtProgressBar(min=0, max=length(job_data), style=3)

    while(submit_index <= length(job_data) || length(jobs_running) > 0) {
        msg = receive.socket(socket)
        if (msg$id == 0)
            send.socket(socket, data=list(fun=fun, const=const), send.more=TRUE)
        else {
            jobs_running = setdiff(jobs_running, msg$id)
            job_result[[msg$id]] = msg$result
        }

        if (submit_index <= length(job_data)) {
            send.socket(socket, data=list(id=submit_index, iter=as.list(job_data[[submit_index]])))
            jobs_running = c(jobs_running, submit_index)
            submit_index = submit_index + 1
        } else
            send.socket(socket, data=list(id=0))

        setTxtProgressBar(pb, submit_index - length(jobs_running))
        Sys.sleep(0.001)
    }

    close(pb)
    job_result
}

if (is.null(module_name())) {
    # test if memory limits raise and error instead of crashing r
    # note that the worker has about 225 MB overhead
    fx = function(x) {
        test = rep(1,x)
        TRUE
    }
    re = Q(fx, (20:50)*1e6, memory=500, n_jobs=1)
    testthat::expect_equal(unique(sapply(re, class)), c("logical", "try-error"))
}
