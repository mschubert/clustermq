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
Q = function(fun, ..., const=list(), expand_grid=FALSE, seed=128965, memory=NULL,
             n_jobs=NULL, job_size=NULL, split_array_by=NA, fail_on_error=TRUE) {
    worker_file = module_file("worker.r") #BUG: in modules, could do this directly otherwise
    lsf_file = module_file("LSF.tmpl") #BUG: same as above
    infuser = import_package('infuser')
    import_package('rzmq', attach=TRUE)

    fun = match.fun(fun)
    exec_socket = 6124
    job_data = .p$process_args(fun, iter=list(...), const=const,
                               expand_grid=expand_grid,
                               split_array_by=split_array_by)
    names(job_data) = 1:length(job_data)

    # use the template & submit
    values = list(
        queue = "research-rh6",
        walltime = 10080,
        memory = memory,
        rscript = worker_file,
        args = sprintf("tcp://%s:%i", Sys.info()[['nodename']], exec_socket)
    )

    # bind socket
    zmq.context = init.context()
    socket = init.socket(zmq.context, "ZMQ_REP")
    bind.socket(socket, paste0("tcp://*:", exec_socket))

    # do the submissions
    for (j in 1:n_jobs) {
        values$job_name = paste0("rzmq-", j)
        values$log_file = paste0(values$job_name, ".log")
        system("bsub", input=infuser$infuse(lsf_file, values))
    }

    job_result = rep(list(NULL), length(job_data))
    job_status = factor(rep("queued", length(job_data)),
                        levels=c("queued", "running", "done", "error"))

    while(any(job_status %in% c("queued", "running"))) {
        msg = receive.socket(socket)
        if (msg$id == 0)
            send.socket(socket, data=list(fun=fun, const=const), send.more=TRUE)
        else {
            job_status[msg$id] = "done"
            job_result[[msg$id]] = msg$result
        }

        id = which(job_status == "queued")[1]
        if (!is.na(id)) {
            send.socket(socket, data=list(id=id, iter=as.list(job_data[[id]])))
            job_status[id] = "running"
        } else
            send.socket(socket, data=list(id=0))

        Sys.sleep(0.001)
    }

    job_result
}
