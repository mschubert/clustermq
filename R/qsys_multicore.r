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
                private$children[[as.character(p$pid)]] = p
            }
            private$workers_total = n_jobs
        },

        cleanup = function(quiet=FALSE) {
            success = super$cleanup(quiet=quiet)
            invisible(success)
        },

        finalize = function() {
            res = suppressWarnings(parallel::mccollect(private$children))
#            kill_pids = names(res)[sapply(res, is.null)]
#            if (length(kill_pids) > 0) {
#                warning("unclean shutdown for pids: ", paste(kill_pids, collapse=", "))
#                tools::pskill(kill_pids, tools::SIGKILL)
#            }
        }
    ),

    private = list(
        children = list()
    )
)
