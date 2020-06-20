#' Process on multiple processes on one machine
#'
#' This makes use of rzmq messaging and sends requests via TCP/IP
#'
#' @keywords internal
MULTIPROCESS = R6::R6Class("MULTIPROCESS",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(..., node="localhost")
        },

        submit_jobs = function(n_jobs, ..., verbose=TRUE) {
            if (verbose)
                message("Starting ", n_jobs, " processes ...")

            for (i in seq_len(n_jobs)) {
                cr = callr::r_bg(function(m) clustermq:::worker(m), args=list(m=private$master))
                private$callr[[as.character(cr$get_pid())]] = cr
            }
            private$workers_total = n_jobs
        },

        cleanup = function(quiet=FALSE, timeout=3) {
            success = super$cleanup(quiet=quiet, timeout=timeout)
            private$callr[sapply(private$callr, function(x) ! x$is_alive())] = NULL
            invisible(success)
        },

        finalize = function(quiet=FALSE) {
            if (!private$is_cleaned_up) {
                private$callr[sapply(private$callr, function(x) ! x$is_alive())] = NULL
                if (!quiet && length(private$callr) > 0)
                    warning("Unclean shutdown for PIDs: ",
                            paste(names(private$callr), collapse=", "), immediate.=TRUE)
                for (cr in private$callr)
                    cr$kill_tree()
                private$is_cleaned_up = TRUE
            }
        }
    ),

    private = list(
        callr = list()
    )
)
