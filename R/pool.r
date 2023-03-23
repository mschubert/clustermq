loadModule("cmq_master", TRUE) # CMQMaster C++ class

#' Class for basic queuing system functions
#'
#' Provides the basic functions needed to communicate between machines
#' This should abstract most functions of rZMQ so the scheduler
#' implementations can rely on the higher level functionality
Pool = R6::R6Class("Pool",
    public = list(
        initialize = function(addr=sample(host()), reuse=TRUE) {
            private$master = methods::new(CMQMaster)
            # ZeroMQ allows connecting by node name, but binding must be either
            # a numerical IP or an interfacet name. This is a bit of a hack to
            # seem to allow node-name bindings
            nodename = Sys.info()["nodename"]
            addr = sub(nodename, "*", addr, fixed=TRUE)
            bound = private$master$listen(addr)
            private$addr = sub("0.0.0.0", nodename, bound, fixed=TRUE)
            private$timer = proc.time()
            private$reuse = reuse
        },

        print = function() {
            cat(sprintf("<clustermq> worker pool with %i member(s)\n", length(private$workers)))
        },

        add = function(qsys, n, ...) {
            self$workers = qsys$new(addr=private$addr, n_jobs=n, ...)
        },

        env = function(...) {
            args = list(...)
            for (name in names(args)) {
#                if (inherits(args[[name]], "function"))
#                    environment(args[[fname]]) = .GlobalEnv
                private$master$add_env(name, args[[name]])
            }
        },

        pkg = function(...) {
            args = as.list(...)
            for (elm in args)
                private$master$add_pkg(elm)
        },

        send = function(cmd, ...) {
            env = list(...)
            for (i in seq_along(cmd[[1]])) {
                name = cmd[[1]][[i]]
                if (is.name(name) && as.character(name) %in% names(env))
                    cmd[[1]][[i]] = env[[as.character(name)]]
            }

            private$master$send(cmd, TRUE)
        },
        send_shutdown = function() {
            private$master$send(expression(proc.time()), FALSE)
        },
        send_wait = function(wait=50) {
            private$master$send(expression(Sys.sleep(wait)), TRUE)
        },

        recv = function() {
            private$master$recv(-1L)
        },

        cleanup = function(timeout=5000) {
            stats = private$master$cleanup(timeout)
            success = self$workers$cleanup()

            times = stats #TODO: mem stats
            # max_mem = Reduce(max, lapply(private$worker_stats, function(w) w$mem))
            max_mb = NA_character_
            # if (length(max_mem) == 1) {
            #     class(max_mem) = "object_size"
            #     max_mb = format(max_mem + 2e8, units="auto") # ~ 200 Mb overhead
            # }

            wt = Reduce(`+`, times) / length(times)
            rt = proc.time() - private$timer
            if (! inherits(wt, "proc_time"))
                wt = rep(NA, 3)

            fmt = "Master: [%.1fs %.1f%% CPU]; Worker: [avg %.1f%% CPU, max %s]"
            message(sprintf(fmt, rt[[3]], 100*(rt[[1]]+rt[[2]])/rt[[3]],
                            100*(wt[[1]]+wt[[2]])/wt[[3]], max_mb))

            invisible(success)
        },

        workers = NULL
    ),

    active = list(
        workers_total = function() -1,
        workers_running = function() -1,
        data_num = function() -1,
        data_size = function() -1,
        reusable = function() private$reuse
    ),

    private = list(
        finalize = function() {
            private$master$close(0L)
        },

        master = NULL,
        addr = NULL,
        timer = NULL,
        reuse = NULL
    ),

    cloneable = FALSE
)
