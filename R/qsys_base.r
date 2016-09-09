#' Class for basic queuing system functions
#'
#' Provides the basic functions needed to communicate between machines
#' This should abstract most functions of rZMQ so the scheduler
#' implementations can rely on the higher level functionality
QSys = R6::R6Class("QSys",
    public = list(
        initialize = function() {
            private$job_num = 1
            private$zmq.context = rzmq::init.context()
        },

        # Submits one job to the queuing system
        #
        # @param memory      The amount of memory (megabytes) to request
        # @param log_worker  Create a log file for each worker
        submit_job = function(...) {
            stop("Derived class needs to overwrite submit_job()")
        },

        # Send the data common to all workers, only serialize once
        send_common_data = function() {
            if (is.null(private$common_data))
                stop("Need to set_common_data() first")

            rzmq::send.socket(socket = private$socket,
                              data = private$common_data,
                              serialize = FALSE,
                              send.more = TRUE)
        },

        # Send iterated data to one worker
        send_job_data = function(...) {
            rzmq::send.socket(socket = private$socket, data = list(...))
        },

        # Read data from the socket
        receive_data = function() {
            rzmq::receive.socket(private$socket)
        },

        # Make sure all resources are closed properly
        cleanup = function() {
        }
    ),

    private = list(
        job_num = NULL,
        zmq.context = NULL,
        socket = NULL,
        port = NULL,
        master = NULL,

        set_common_data = function(fun, const, seed) {
            private$common_data = serialize(list(fun=fun, const=const, seed=seed), NULL)
        },

        # Create a socket and listen on a port in range
        #
        # @param fun    The function to be called
        # @param const  Constant arguments to the function call
        # @param seed   Common seed (to be used w/ job ID)
        # @return       Sets "port" and "master" attributes
        listen_socket = function(min_port, max_port=min_port, n_tries=100) {
            private$socket = rzmq::init.socket(private$zmq.context, "ZMQ_REP")

            sink('/dev/null')
            for (i in 1:n_tries) {
                exec_socket = sample(min_port:max_port, size=1)
                addr = paste0("tcp://*:", exec_socket)
                port_found = rzmq::bind.socket(private$socket, addr)
                if (port_found)
                    break
            }
            sink()

            if (!port_found)
                stop("Could not bind to port range (6000,8000) after 100 tries")

            private$port = exec_socket
            private$master = sprintf("tcp://%s:%i", Sys.info()[['nodename']], exec_socket)
        }
    ),

    cloneable = FALSE
)
