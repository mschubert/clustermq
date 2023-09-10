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
            cat(sprintf("<clustermq> worker pool with %i member(s)\n", self$workers$n()))
        },

        list = function() {
            info = private$master$list_workers()
            times = do.call(rbind, info$time)[,1:3]
            data.frame(worker=info$worker, status=info$status, times)
        },

        add = function(qsys, n, ...) {
            self$workers = qsys$new(addr=private$addr, master=private$master, n_jobs=n, ...)
        },

        env = function(...) {
            args = list(...)
            for (name in names(args)) {
#                if (inherits(args[[name]], "function"))
#                    environment(args[[fname]]) = .GlobalEnv
                private$master$add_env(name, args[[name]])
            }
            invisible(private$master$list_env())
        },

        pkg = function(...) {
            args = as.list(...)
            for (elm in args)
                private$master$add_pkg(elm)
        },

        ### START pre-0.9 compatibility functions (deprecated)
        set_common_data = function(..., export=list(), pkgs=c(), token="") {
            .Deprecated("env")
            do.call(self$env, c(list(...), export))
            if (length(pkgs) > 0)
                do.call(self$pkg, as.list(pkgs))
            private$token = token
        },
        send_common_data = function() {
            .Deprecated("handled implicitly")
            self$send()
        },
        send_shutdown_worker = function() {
            .Deprecated("send_shutdown")
            self$send_shutdown()
        },
        send_call = function(expr, env=list(), ref=substitute(expr)) {
            .Deprecated("send")
            pcall = quote(substitute(expr))
            do.call(self$send, c(list(cmd=eval(pcall)), env))
        },
        receive_data = function() {
            .Deprecated("recv")
            rd = self$recv()
            list(result=rd, warnings=c(), errors=c(), token=private$token)
        },
        ### END pre-0.9 compatibility functions (deprecated)

        send = function(cmd, ...) {
            pcall = quote(substitute(cmd))
            cmd = as.expression(do.call(substitute, list(eval(pcall), env=list(...))))
            private$master$send(cmd)
        },
        send_shutdown = function() {
            private$master$send_shutdown()
        },
        send_wait = function(wait=50) {
            private$master$send(Sys.sleep(wait/1000))
        },

        recv = function() {
            private$master$recv(-1L)
        },

        cleanup = function(timeout=5000) {
            private$master$close(timeout)
            # ^^ replace with: (1) try close connections, and (2) close socket

            times = private$master$list_workers()$time
            times = times[sapply(times, length) != 0]
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

            invisible(TRUE)
        },

        workers = NULL
    ),

    active = list(
        workers_total = function() self$workers$n(),
        workers_running = function() length(private$master$list_workers()$worker),
        reusable = function() private$reuse
    ),

    private = list(
        finalize = function() {
            private$master$close(0L)
        },

        token = NULL, ### pre-0.9 compatibility functions (deprecated)

        master = NULL,
        addr = NULL,
        timer = NULL,
        reuse = NULL
    ),

    cloneable = FALSE
)
