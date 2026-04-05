loadModule("cmq_master", TRUE) # CMQMaster C++ class

#' Class for basic queuing system functions
#'
#' Provides the basic functions needed to communicate between machines
#' This should abstract most functions of rZMQ so the scheduler
#' implementations can rely on the higher level functionality
#'
#' @keywords internal
Pool = R6::R6Class("Pool",
    public = list(
        initialize = function(addr=sample(host()), reuse=TRUE) {
            private$master = methods::new(CMQMaster)
            # ZeroMQ allows connecting by node name, but binding must be either
            # a numerical IP or an interface name. This is a bit of a hack to
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

        info = function() {
            info = private$master$list_workers()
            times = do.call(rbind, info$time)[,1:3,drop=FALSE]
            mem = do.call(rbind, info$mem)
            do.call(data.frame, c(info[c("worker", "status")], current=list(info$worker==info$cur),
                                  info["calls"], as.data.frame(times), mem=as.data.frame(mem)))
        },
        current = function() {
            private$master$current()
        },

        add = function(qsys, n, ...) {
            self$workers = qsys$new(addr=private$addr, master=private$master, n_jobs=n, ...)
        },

        env = function(...) {
            args = list(...)
            for (name in names(args))
                private$master$add_env(name, args[[name]])
            if (length(args) == 0)
                private$master$list_env()
            else
                invisible(private$master$list_env())
        },

        pkg = function(...) {
            args = as.list(...)
            for (elm in args)
                private$master$add_pkg(elm)
        },

        send_eval = function(cmd, ...) {
            pcall = quote(substitute(cmd))
            cmd = as.expression(do.call(substitute, list(eval(pcall), env=list(...))))
            invisible(private$master$send_eval(cmd))
        },
        send = function(cmd, ...) {
            .Deprecated("send_eval")
            pcall = quote(substitute(cmd))
            cmd = as.expression(do.call(substitute, list(eval(pcall), env=list(...))))
            invisible(private$master$send_eval(cmd))
        },
        send_shutdown = function() {
            private$master$send_shutdown()
        },
        send_wait = function(wait=50) {
            .Deprecated("send_eval")
            self$send_eval(Sys.sleep(wait/1000), wait=wait)
        },

        recv = function(timeout=-1L) {
            private$master$recv(timeout)
        },

        cleanup = function(timeout=5) {
            success = private$master$close(as.integer(timeout*1000))
            success = self$workers$cleanup(success, timeout) # timeout left?

            info = self$info()
            max_mem = max(c(0, info$mem.max), na.rm=TRUE)
            max_mem_str = format(structure(max_mem, class="object_size"), units="auto")
            if (max_mem_str == "0 bytes")
                max_mem_str = "NA"

            if (nrow(info) > 0) {
                wt = lapply(info[c("user.self", "sys.self", "elapsed")], mean, na.rm=TRUE)
            } else {
                wt = rep(NA, 3)
            }
            rt = proc.time() - private$timer
            rt3_fmt = difftime(as.POSIXct(rt[[3]], origin="1970-01-01"),
                               as.POSIXct(0, origin="1970-01-01"), units="auto")
            rt3_str = sprintf("%.1f %s", rt3_fmt, attr(rt3_fmt, "units"))

            fmt = "Master: [%s %.1f%% CPU]; Worker: [avg %.1f%% CPU, max %s]"
            message(sprintf(fmt, rt3_str, 100*(rt[[1]]+rt[[2]])/rt[[3]],
                            100*(wt[[1]]+wt[[2]])/wt[[3]], max_mem_str))

            invisible(success)
        },

        workers = NULL
    ),

    active = list(
        workers_total = function() private$master$workers_total(),
        workers_running = function() private$master$workers_running(),
        reusable = function() private$reuse
    ),

    private = list(
        master = NULL,
        addr = NULL,
        timer = NULL,
        reuse = NULL,

        finalize = function() {
            private$master$close(0L)
        }
    ),

    cloneable = FALSE
)
