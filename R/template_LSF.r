#' A template string used to submit jobs
template = "#BSUB-J {{ job_name }}        # name of the job / array jobs
#BSUB-g {{ job_group | /rzmq }}           # group the job belongs to
#BSUB-o {{ log_file | /dev/null }}        # output is sent to logfile, stdout + stderr by default
#BSUB-M {{ memory | 4096 }}               # Memory requirements in Mbytes
#BSUB-R rusage[mem={{ memory | 4096  }}]  # Memory requirements in Mbytes

R --no-save --no-restore -e \\
    'clustermq:::worker(\"{{ job_name }}\", \"{{ master }}\", {{ memory }})'
"

#' Objects that are linked to the package instance
pkg_env = new.env()

#' Initialize the rZMQ context and bind the port
#'
#' @return  ID of the job group
init = function() {
    # be sure our variables are set right to start out with
    do.call(rm, c(as.list(ls(pkg_env)), list(envir=pkg_env)))
    pkg_env$job_num = 1
    pkg_env$zmq.context = rzmq::init.context()

    # bind socket
    pkg_env$socket = rzmq::init.socket(pkg_env$zmq.context, "ZMQ_REP")

    sink('/dev/null')
    for (i in 1:100) {
        exec_socket = sample(6000:8000, size=1)
        port_found = rzmq::bind.socket(pkg_env$socket,
                                       paste0("tcp://*:", exec_socket))
        if (port_found)
            break
    }
    sink()

    if (!port_found)
        stop("Could not bind to port range (6000,8000) after 100 tries")

    pkg_env$master = sprintf("tcp://%s:%i", Sys.info()[['nodename']], exec_socket)
    exec_socket
}

#' Submits one job to the queuing system
#'
#' @param memory      The amount of memory (megabytes) to request
#' @param log_worker  Create a log file for each worker
submit_job = function(memory, log_worker=FALSE) {
    if (is.null(pkg_env$master))
        stop("Need to call init() first")

    pkg_env$group_id = rev(strsplit(pkg_env$master, ":")[[1]])[1]
    pkg_env$job_name = paste0("rzmq", pkg_env$group_id, "-", pkg_env$job_num)

    values = list(
        job_name = pkg_env$job_name,
        job_group = paste("/rzmq", pkg_env$group_id, sep="/"),
        master = pkg_env$master,
        memory = memory
    )

    pkg_env$job_group = values$job_group
    pkg_env$job_num = pkg_env$job_num + 1

    if (log_worker)
        values$log_file = paste0(values$job_name, ".log")

    job_input = infuser::infuse(template, values)
    system("bsub", input=job_input, ignore.stdout=TRUE)
}

#' Read data from the socket
receive_data = function() {
	rzmq::receive.socket(pkg_env$socket)
}

#' Send the data common to all workers, only serialize once
send_common_data = function(...) {
	if (is.null(pkg_env$common_data))
        pkg_env$common_data = serialize(list(...), NULL)

	rzmq::send.socket(socket = pkg_env$socket,
                      data = pkg_env$common_data,
                      serialize = FALSE,
                      send.more = TRUE)
}

#' Send iterated data to one worker
send_job_data = function(...) {
	rzmq::send.socket(socket = pkg_env$socket, data = list(...))
}

#' Will be called when exiting the `hpc` module's main loop, use to cleanup
cleanup = function() {
    system(paste("bkill -g", pkg_env$job_group, "0"), ignore.stdout=FALSE)
}
