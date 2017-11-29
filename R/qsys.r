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
        initialize = function(data=NULL, reuse=FALSE, ports=6000:8000, master=NULL,
                              protocol="tcp", node=Sys.info()[['nodename']]) {
            private$zmq_context = rzmq::init.context(3L)
            private$socket = rzmq::init.socket(private$zmq_context, "ZMQ_REP")
            private$port = bind_avail(private$socket, ports)
            private$listen = sprintf("%s://%s:%i", protocol, node, private$port)
            private$timer = proc.time()
            private$reuse = reuse

            if (is.null(master))
                private$master = private$listen
            else
                private$master = master

            if (!is.null(data))
                do.call(self$set_common_data, data)
        },

        # Submits jobs to the cluster system
        #
        # This needs to be overwritten in the derived class and only
        # produces an error if called directly
        submit_jobs = function(...) {
            stop(sQuote(submit_jobs), " must be overwritten")
        },

        # Sets the common data as an rzmq message object
        set_common_data = function(...) {
            args = list(...)
            for (n in names(args)) {
                obj = args[[n]]
                if (is.call(obj) || is.name(obj))
                    args[[n]] = eval(obj, envir=parent.frame())
            }

            if ("fun" %in% names(args))
                environment(args$fun) = .GlobalEnv

            if ("token" %in% names(args))
                private$token = args$token
            else {
                private$token = paste(sample(letters, 5, TRUE), collapse="")
                args$token = private$token
            }
            private$common_data = rzmq::init.message(c(list(id="DO_SETUP"), args))
        },

        # Send the data common to all workers, only serialize once
        send_common_data = function() {
            if (is.null(private$common_data))
                stop("Need to set_common_data() first")

            rzmq::send.message.object(private$socket, private$common_data)
            private$workers_up = private$workers_up + 1
        },

        # Send iterated data to one worker
        send_job_data = function(...) {
            private$send(id="DO_CHUNK", token=private$token, ...)
        },

        # Wait for a total of 50 ms
        send_wait = function() {
            private$send(id="WORKER_WAIT", wait=0.05*self$workers_running)
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

        # Send shutdown signal to worker
        send_shutdown_worker = function() {
            private$send(id="WORKER_STOP")
        },

        disconnect_worker = function(msg) {
            private$send()
            private$workers_up = private$workers_up - 1
            private$worker_stats = c(private$worker_stats, list(msg))
        },

        # Make sure all resources are closed properly
        cleanup = function() {
            while(self$workers_running > 0) {
                msg = self$receive_data(timeout=5)
                if (is.null(msg)) {
                    warning(sprintf("%i/%i workers did not shut down properly",
                            self$workers_running, self$workers), immediate.=TRUE)
                    break
                } else if (msg$id == "WORKER_READY")
                    self$send_shutdown_worker()
                else if (msg$id == "WORKER_DONE")
                    self$disconnect_worker(msg)
                else
                    warning("something went wrong during cleanup")
            }

            # compute summary statistics for workers
            times = lapply(private$worker_stats, function(w) w$time)
            mem = sapply(private$worker_stats, function(w) w$mem)
            wt = Reduce(`+`, times) / length(times)
            rt = proc.time() - private$timer
            fmt = "Master: [%.1fs %.1f%% CPU]; Worker: [avg %.1f%% CPU, max %.1f Mb]"
            message(sprintf(fmt, rt[[3]], 100*(rt[[1]]+rt[[2]])/rt[[3]],
                            100*(wt[[1]]+wt[[2]])/wt[[3]], max(mem)))
        }
    ),

    active = list(
        id = function() private$port,
        url = function() private$listen,
        sock = function() private$socket,
        workers = function() private$workers_total,
        workers_running = function() private$workers_up,
        data_token = function() private$token,
        reusable = function() private$reuse
    ),

    private = list(
        zmq_context = NULL,
        socket = NULL,
        port = NA,
        master = NULL,
        listen = NULL,
        timer = NULL,
        common_data = NULL,
        token = "not set",
        workers_total = 0,
        workers_up = 0,
        worker_stats = list(),
        reuse = NULL,

        send = function(..., serialize=TRUE) {
            rzmq::send.socket(socket = private$socket,
                              data = list(...),
                              serialize = serialize)
        }
    ),

    cloneable = FALSE
)
