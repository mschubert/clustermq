loadModule("cmq_master", TRUE) # CMQMaster C++ class

#' Class for basic queuing system functions
#'
#' Provides the basic functions needed to communicate between machines
#' This should abstract most functions of rZMQ so the scheduler
#' implementations can rely on the higher level functionality
Pool = R6::R6Class("Pool",
    public = list(
        initialize = function(addr=host()) {
            private$master = methods::new(CMQMaster)
            # ZeroMQ allows connecting by node name, but binding must be either
            # a numerical IP or an interfacet name. This is a bit of a hack to
            # seem to allow node-name bindings
            nodename = Sys.info()["nodename"]
            addr = sub(nodename, "*", addr, fixed=TRUE)
            bound = private$master$listen(addr)
            private$addr = sub("0.0.0.0", nodename, bound, fixed=TRUE)
            private$timer = proc.time()
        },

        print = function() {
            cat(sprintf("<clustermq> worker pool with %i member(s)\n", length(private$workers)))
        },

        add = function(qsys, n) {
            private$workers = qsys$new(addr=private$addr)
            private$workers$submit_jobs(n)
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
            args = list(...)
            for (elm in args)
                private$master$add_pkg(elm)
        },

        send = function(cmd) {
            private$master$send(cmd, TRUE)
        },
        send_shutdown = function() {
            # ..starttime.. in worker() .GlobalEnv
            private$master$send(expression(proc.time() - ..starttime..), FALSE)
        },
        send_wait = function(wait=50) {
            private$master$send(expression(Sys.sleep(wait)), TRUE)
        },

        recv = function() {
            private$master$recv(-1L)
        },

        cleanup = function(timeout=5000) {
            stats = private$master$cleanup(timeout)
            private$workers$cleanup()

            times = stats #TODO: mem stats
            # max_mem = Reduce(max, lapply(private$worker_stats, function(w) w$mem))
            max_mb = NA_character_
            # if (length(max_mem) == 1) {
            #     class(max_mem) = "object_size"
            #     max_mb = format(max_mem + 2e8, units="auto") # ~ 200 Mb overhead
            # }

            wt = Reduce(`+`, times) / length(times)
            rt = proc.time() - private$timer
            if (class(wt) != "proc_time")
                wt = rep(NA, 3)

            fmt = "Master: [%.1fs %.1f%% CPU]; Worker: [avg %.1f%% CPU, max %s]"
            message(sprintf(fmt, rt[[3]], 100*(rt[[1]]+rt[[2]])/rt[[3]],
                            100*(wt[[1]]+wt[[2]])/wt[[3]], max_mb))
        }
    ),

    private = list(
        finalize = function() {
            private$workers$cleanup()
            private$master$close(0L)
        },

        master = NULL,
        addr = NULL,
        workers = NULL,
        timer = NULL
    ),

    cloneable = FALSE
)
