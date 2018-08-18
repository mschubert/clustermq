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

        cleanup = function(quiet=FALSE, timeout=3) {
            success = super$cleanup(quiet=quiet, timeout=timeout)
            private$collect_children(wait=success, timeout=timeout)
            invisible(success && length(private$children) == 0)
        },

        finalize = function() {
            private$collect_children(wait=FALSE, timeout=0)
            running = names(private$children)
            if (length(running) > 0) {
                warning("Unclean shutdown for PIDs: ", paste(running, collapse=", "))
                tools::pskill(running, tools::SIGKILL)
            }
        }
    ),

    private = list(
        collect_children = function(...) {
            pids = as.integer(names(private$children))
            res = suppressWarnings(parallel::mccollect(pids, ...))
            finished = intersect(names(private$children), names(res))
            private$children[finished] = NULL
        },

        children = list()
    )
)
