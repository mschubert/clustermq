#' Process on multiple cores on one machine
#'
#' This makes use of rzmq messaging and sends requests via TCP/IP
MULTICORE = R6::R6Class("MULTICORE",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(..., node="localhost")
        },

        submit_jobs = function(n_jobs, template=list(), log_worker=FALSE) {
            cmd = quote(clustermq:::worker(private$master, verbose=FALSE))
            for (i in seq_len(n_jobs)) {
                p = parallel::mcparallel(cmd, silent=TRUE, detached=TRUE)
                private$pids = c(private$pids, p$pid)
            }
            private$workers_total = n_jobs
        },

        cleanup = function() {
            success = super$cleanup()
            self$finalize(success)
        },

        finalize = function(clean=FALSE) {
            if (length(private$pids) > 0) {
                tools::pskill(private$pids, tools::SIGKILL)
                private$pids = NULL
            }
        }
    ),

    private = list(
        pids = NULL
    )
)
