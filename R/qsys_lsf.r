#' Environment for the queueing system
lsf = new.env()

#' A template string used to submit jobs
lsf$template = "#BSUB-J {{ job_name }}        # name of the job / array jobs
#BSUB-g {{ job_group | /rzmq }}           # group the job belongs to
#BSUB-o {{ log_file | /dev/null }}        # stdout + stderr
#BSUB-M {{ memory | 4096 }}               # Memory requirements in Mbytes
#BSUB-R rusage[mem={{ memory | 4096  }}]  # Memory requirements in Mbytes

R --no-save --no-restore -e \\
    'clustermq:::worker(\"{{ job_name }}\", \"{{ master }}\", {{ memory }})'
"

#' Initialize the rZMQ context and bind the port
#'
#' @param fun    The function to be called
#' @param const  Constant arguments to the function call
#' @param seed   Common seed (to be used w/ job ID)
#' @return       ID of the job group
lsf$init = function(fun, const, seed) {
    # be sure our variables are set right to start out with
#    do.call(rm, c(as.list(ls(lsf)), list(envir=lsf)))
    lsf$job_num = 1
    lsf$zmq.context = rzmq::init.context()
    lsf$common_data = serialize(list(fun=fun, const=const, seed=seed), NULL)

    # bind socket
    lsf$socket = rzmq::init.socket(lsf$zmq.context, "ZMQ_REP")

    sink('/dev/null')
    for (i in 1:100) {
        exec_socket = sample(6000:8000, size=1)
        addr = paste0("tcp://*:", exec_socket)
        port_found = rzmq::bind.socket(lsf$socket, addr)
        if (port_found)
            break
    }
    sink()

    if (!port_found)
        stop("Could not bind to port range (6000,8000) after 100 tries")

    lsf$master = sprintf("tcp://%s:%i", Sys.info()[['nodename']], exec_socket)
    exec_socket
}

#' Submits one job to the queuing system
#'
#' @param memory      The amount of memory (megabytes) to request
#' @param log_worker  Create a log file for each worker
lsf$submit_job = function(memory, log_worker=FALSE) {
    if (is.null(lsf$master))
        stop("Need to call init() first")

    lsf$group_id = rev(strsplit(lsf$master, ":")[[1]])[1]
    lsf$job_name = paste0("rzmq", lsf$group_id, "-", lsf$job_num)

    values = list(
        job_name = lsf$job_name,
        job_group = paste("/rzmq", lsf$group_id, sep="/"),
        master = lsf$master,
        memory = memory
    )

    lsf$job_group = values$job_group
    lsf$job_num = lsf$job_num + 1

    if (log_worker)
        values$log_file = paste0(values$job_name, ".log")

    job_input = infuser::infuse(lsf$template, values)
    system("bsub", input=job_input, ignore.stdout=TRUE)
}

#' Read data from the socket
lsf$receive_data = function() {
    rzmq::receive.socket(lsf$socket)
}

#' Send the data common to all workers, only serialize once
lsf$send_common_data = function() {
    if (is.null(lsf$common_data))
        stop("Need to call init() first")

    rzmq::send.socket(socket = lsf$socket,
                      data = lsf$common_data,
                      serialize = FALSE,
                      send.more = TRUE)
}

#' Send iterated data to one worker
lsf$send_job_data = function(...) {
    rzmq::send.socket(socket = lsf$socket, data = list(...))
}

#' Will be called when exiting the `hpc` module's main loop, use to cleanup
lsf$cleanup = function() {
    system(paste("bkill -g", lsf$job_group, "0"), ignore.stdout=FALSE)
}
