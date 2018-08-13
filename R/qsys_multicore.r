#' Process on multiple cores on one machine
#'
#' This makes use of rzmq messaging and sends requests via TCP/IP
MULTICORE = R6::R6Class("MULTICORE",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(..., node="localhost")
        },

        submit_jobs = function(n_jobs, ...) {
            cmd = quote(clustermq:::worker(private$master, verbose=FALSE))
            for (i in seq_len(n_jobs)) {
                p = parallel::mcparallel(cmd, silent=TRUE)
                private$children[[p$pid]] = p
            }
            private$workers_total = n_jobs
        },

        cleanup = function(quiet=FALSE) {
            success = super$cleanup(quiet=quiet)
            self$finalize()
            invisible(success)
        },

        finalize = function() {
            for (pid in names(private$children)) {
                res = parallel::mccollect(private$children[[pid]],
                                          wait=FALSE, timeout=0.5)
                if (is.null(res))
                    tools::pskill(pid, tools::SIGKILL)
                private$children[[pid]] = NULL
            }
        }
    ),

    private = list(
        children = list()
    )
)
