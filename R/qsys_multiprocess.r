#' Process on multiple processes on one machine
#'
#' Derives from QSys to provide callr-specific functions
#'
#' @keywords internal
MULTIPROCESS = R6::R6Class("MULTIPROCESS",
    inherit = QSys,

    public = list(
        initialize = function(addr=host("127.0.0.1"), ...) {
            if (! requireNamespace("callr", quietly=TRUE))
                stop("The ", sQuote(callr), " package is required for ", sQuote("multiprocess"))
            super$initialize(addr=addr, ...)
        },

        submit_jobs = function(n_jobs, ..., log_file="|", log_worker=FALSE, verbose=TRUE) {
            if (verbose)
                message("Starting ", n_jobs, " processes ...")

            if (log_worker && log_file == "|")
                log_file = "cmq-%i.log"

            for (i in seq_len(n_jobs)) {
                log_i = sprintf(log_file, i)
                cr = callr::r_bg(function(m) clustermq:::worker(m),
                                 args=list(m=private$master),
                                 stdout=log_i, stderr=log_i)
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
