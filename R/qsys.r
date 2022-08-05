loadModule("cmq_master", TRUE) # CMQMaster C++ class

#' Class for basic queuing system functions
#'
#' Provides the basic functions needed to communicate between machines
#' This should abstract most functions of rZMQ so the scheduler
#' implementations can rely on the higher level functionality
#'
#' @keywords internal
QSys = R6::R6Class("QSys",
    public = list(
        # Create a class instance
        #
        # Initializes ZeroMQ and sets and sets up our primary communication socket
        #
        # @param addr    Vector of possible addresses to bind
        # @param bind    Whether to bind 'addr' or just refer to it
        # @param data    List with elements: fun, const, export, seed
        initialize = function(addr=host(), bind=TRUE, data=NULL, reuse=FALSE,
                              template=NULL, zmq=methods::new(CMQMaster)) {
            private$zmq = zmq
            if (bind) {
                # ZeroMQ allows connecting by node name, but binding must be either
                # a numerical IP or an interfacet name. This is a bit of a hack to
                # seem to allow node-name bindings
                nodename = Sys.info()["nodename"]
                addr = sub(nodename, "*", addr, fixed=TRUE)
                bound = private$zmq$listen(addr)
                # Change "all interfaces" to the node name so we can connect to it
                private$master = sub("0.0.0.0", nodename, bound, fixed=TRUE)
            } else
                private$master = addr # net_fwd for proxy
            private$port = as.integer(sub(".*:", "", private$master))
            private$timer = proc.time()
            private$reuse = reuse

            if (!is.null(template)) {
                if (!file.exists(template))
                    template = system.file(paste0(template, ".tmpl"),
                                           package="clustermq", mustWork=TRUE)
                if (file.exists(template))
                    private$template = readChar(template, file.info(template)$size)
                else
                    stop("Template file does not exist: ", sQuote(template))
            }
            private$defaults = getOption("clustermq.defaults", list())

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

        # Evaluate an arbitrary expression on a worker
        send_call = function(expr, env=list(), ref=substitute(expr)) {
            private$send_work(id="DO_CALL", expr=substitute(expr), env=env, ref=ref)
        },

        # Sets the common data as an zeromq message object
        set_common_data = function(...) {
            args = lapply(list(...), force)
            if ("fun" %in% names(args))
                environment(args$fun) = .GlobalEnv

            if ("token" %in% names(args))
                private$token = args$token
            else {
                private$token = paste(sample(letters, 5, TRUE), collapse="")
                args$token = private$token
            }
            private$common_data = serialize(c(list(id="DO_SETUP"), args), NULL)
            private$size_common = object.size(private$common_data)
            common_mb = format(private$size_common, units="Mb")
            if (common_mb > getOption("clustermq.data.warning", 1000))
                warning("Common data is ", common_mb, ". Recommended limit ",
                        "is ", getOption("clustermq.data.warning"),
                        " (set by clustermq.data.warning option)", immediate.=TRUE)
            private$n_common = length(args$const) + length(args$export)
            args$token
        },

        # Send the data common to all workers, only serialize once
        send_common_data = function() {
            if (is.null(private$common_data))
                stop("Need to set_common_data() first")
            private$zmq$send_work(private$common_data)
        },

        # Send iterated data to one worker
        send_job_data = function(...) {
            private$send_work(id="DO_CHUNK", token=private$token, ...)
        },

        # Wait for a total of 50 ms
        send_wait = function(wait=0.05*self$workers_running) {
            private$send_work(id="WORKER_WAIT", wait=wait)
        },

        # Read data from the socket
        receive_data = function(timeout=Inf, with_checks=TRUE) {
            if (private$workers_total == 0 && with_checks)
                stop("Trying to receive data without workers")

            if (is.infinite(timeout))
                msec = -1L
            else
                msec = as.integer(timeout * 1000)

            msg = private$zmq$poll_recv(msec)

            if (private$auth != "" && (is.null(msg$auth) || msg$auth != private$auth))
                stop("Authentication provided by worker does not match")

            switch(msg$id,
                "WORKER_UP" = {
                    if (!is.null(private$pkg_warn) && msg$pkgver != private$pkg_warn) {
                        warning("\nVersion mismatch: master has ", private$pkg_warn,
                                ", worker ", msg$pkgver, immediate.=TRUE)
                    }
                    private$pkg_warn = NULL
                    msg$id = "WORKER_READY"
                    msg$token = "not set"
                    private$workers_up = private$workers_up + 1
                },
                "WORKER_DONE" = {
                    private$disconnect_worker(msg)
                    if (private$workers_up > 0)
                        return(self$receive_data(timeout, with_checks=with_checks))
                    else if (with_checks)
                        stop("Trying to receive data after work finished")
                },
                "WORKER_ERROR" = stop("\nWORKER_ERROR: ", msg$msg)
            )
            msg
        },

        # Send shutdown signal to worker
        send_shutdown_worker = function() {
            private$zmq$send_shutdown(data=list(id="WORKER_STOP"))
        },

        # Make sure all resources are closed properly
        cleanup = function(quiet=FALSE, timeout=5) {
            while(private$workers_up > 0) {
                msg = self$receive_data(timeout=timeout, with_checks=FALSE)
                if (is.null(msg)) {
                    warning(sprintf("%i/%i workers did not shut down properly",
                            self$workers_running, self$workers), immediate.=TRUE)
                    break
                }
                switch(msg$id,
                    "WORKER_UP" = {
                        self$workers_running = self$workers_running + 1
                        self$send_shutdown_worker()
                    },
                    "WORKER_READY" = self$send_shutdown_worker(),
                    "WORKER_DONE" = next,
                    warning("Unexpected message ID: ", sQuote(msg$id))
                )
            }

            success = self$workers == 0
            if (!quiet)
                private$summary_stats()
            if (!success)
                self$finalize(quiet=(quiet || self$workers_running == 0))
            private$is_cleaned_up = TRUE
            invisible(success)
        }
    ),

    active = list(
        id = function() private$port,
        workers = function() ifelse(private$is_cleaned_up, 0, private$workers_total),
        workers_running = function() private$workers_up,
        data_token = function() private$token,
        data_num = function() private$n_common,
        data_size = function() private$size_common,
        reusable = function() private$reuse
    ),

    private = list(
        zmq = NULL,
        port = NA,
        master = NULL,
        timer = NULL,
        common_data = NULL,
        n_common = 0,
        size_common = 0,
        token = NA,
        workers_total = 0,
        workers_up = 0,
        worker_stats = list(),
        reuse = NULL,
        template = NULL,
        defaults = list(),
        is_cleaned_up = FALSE,
        pkg_warn = utils::packageVersion("clustermq"),
        auth = "",

        send_work = function(...) {
            private$zmq$send_work(data = list(...))
        },

        disconnect_worker = function(msg) {
            private$zmq$send_shutdown(list())
#            private$zmq$disconnect() #FIXME: disconnect worker, don't close socket
            private$workers_up = private$workers_up - 1
            private$workers_total = private$workers_total - 1
            private$worker_stats = c(private$worker_stats, list(msg))
        },

        fill_options = function(...) {
            values = utils::modifyList(private$defaults, list(...))
            values$master = private$master
            if (grepl("CMQ_AUTH", private$template)) {
                # note: auth will be obligatory in the future and this check will
                #   be removed (i.e., filling will fail if no field in template)
                values$auth = private$auth = paste(sample(letters, 5, TRUE), collapse="")
            } else {
                values$auth = NULL
                warning("Add 'CMQ_AUTH={{ auth }}' to template to enable socket authentication",
                        immediate.=TRUE)
            }
            if (!"job_name" %in% names(values))
                values$job_name = paste0("cmq", private$port)
            private$workers_total = values$n_jobs
            values
        },

        summary_stats = function() {
            times = lapply(private$worker_stats, function(w) w$time)
            max_mem = Reduce(max, lapply(private$worker_stats, function(w) w$mem))
            max_mb = NA_character_
            if (length(max_mem) == 1) {
                class(max_mem) = "object_size"
                max_mb = format(max_mem + 2e8, units="auto") # ~ 200 Mb overhead
            }

            wt = Reduce(`+`, times) / length(times)
            rt = proc.time() - private$timer
            if (class(wt) != "proc_time")
                wt = rep(NA, 3)

            fmt = "Master: [%.1fs %.1f%% CPU]; Worker: [avg %.1f%% CPU, max %s]"
            message(sprintf(fmt, rt[[3]], 100*(rt[[1]]+rt[[2]])/rt[[3]],
                            100*(wt[[1]]+wt[[2]])/wt[[3]], max_mb))
        }
    ),

    cloneable = FALSE
)
