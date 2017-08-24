#' Class for basic queuing system functions
#'
#' Provides the basic functions needed to communicate between machines
#' This should abstract most functions of rZMQ so the scheduler
#' implementations can rely on the higher level functionality
QSys = R6::R6Class("QSys",
    public = list(
        # Create a class instance
        #
        # Initializes ZeroMQ and sets and sets up our primary communication socket
        #
        # @param data    List with elements: fun, const, export, seed
        # @param ports   Range of ports to choose from
        # @param master  rZMQ address of the master (if NULL we create it here)
        initialize = function(data=NULL, ports=6000:8000, master=NULL) {
            private$job_num = 1
            private$zmq_context = rzmq::init.context()

            private$socket = rzmq::init.socket(private$zmq_context, "ZMQ_REP")
            private$port = bind_avail(private$socket, ports)
            private$listen = sprintf("tcp://%s:%i",
                                     Sys.info()[['nodename']], private$port)

            if (is.null(master))
                private$master = private$listen
            else
                private$master = master

            if (!is.null(data))
                do.call(private$set_common_data, data)
        },

        # Provides values for job submission template
        #
        # Overwrite this in each derived class
        #
        # @param memory      The amount of memory (megabytes) to request
        # @param log_worker  Create a log file for each worker
        # @return  A list with values:
        #   job_name  : An identifier for the current job
        #   job_group : An common identifier for all jobs handled by this qsys
        #   master    : The rzmq address of the qsys instance we listen on
        #   template  : Named list of template values
        #   log_file  : File name to log workers to
        submit_job = function(template=list(), log_worker=FALSE) {
            # if not called from derived
            # stop("Derived class needs to overwrite submit_job()")

            if (!identical(grepl("://[^:]+:[0-9]+", private$master), TRUE))
                stop("Need to initialize QSys first")

            values = list(
                job_name = paste0("cmq", private$port, "-", private$job_num),
                job_group = paste("/cmq", Sys.info()[['nodename']], private$port, sep="/"),
                master = private$master
            )
            if (log_worker)
                values$log_file = paste0(values$job_name, ".log")

            private$job_group = values$job_group
            private$job_num = private$job_num + 1

            utils::modifyList(template, values)
        },

        # Send the data common to all workers, only serialize once
        send_common_data = function() {
            if (is.null(private$common_data))
                stop("Need to set_common_data() first")

            rzmq::send.socket(socket = private$socket,
                              data = private$common_data,
                              serialize = FALSE)
        },

        # Send iterated data to one worker
        send_job_data = function(...) {
            rzmq::send.socket(socket = private$socket, data = list(...))
        },

        # Read data from the socket
        receive_data = function(timeout=-1L) {
            rcv = rzmq::poll.socket(list(private$socket),
                                    list("read"), timeout=timeout)

            if (rcv[[1]]$read)
                rzmq::receive.socket(private$socket)
            else # timeout reached
                NULL
        },

        # Make sure all resources are closed properly
        cleanup = function(dirty=FALSE) {
        }
    ),

    active = list(
        # We use the listening port as scheduler ID
        id = function() private$port,
        url = function() private$listen,
        sock = function() private$socket
    ),

    private = list(
        zmq_context = NULL,
        socket = NULL,
        port = NA,
        master = NULL,
        listen = NULL,
        job_group = NULL,
        job_num = NULL,
        common_data = NULL,

        set_common_data = function(...) {
            private$common_data = serialize(list(...), NULL)
        }
    ),

    cloneable = FALSE
)
