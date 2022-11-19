#' Process on multiple processes on one machine
#'
#' Derives from QSys to provide callr-specific functions
#'
#' @keywords internal
MULTIPROCESS = R6::R6Class("MULTIPROCESS",
    inherit = QSys,

    public = list(
        initialize = function(addr, ...) {
            if (! requireNamespace("callr", quietly=TRUE))
                stop("The ", sQuote(callr), " package is required for ", sQuote("multiprocess"))
            super$initialize(addr=addr, ...)
        },

        submit_jobs = function(n_jobs, ..., log_worker=FALSE, log_file=NULL, verbose=TRUE) {
            if (verbose)
                message("Starting ", n_jobs, " processes ...")

            if (log_worker && is.null(log_file))
                log_file = sprintf("cmq%i-%%i.log", private$port)

            for (i in seq_len(n_jobs)) {
                if (is.character(log_file))
                    log_i = suppressWarnings(sprintf(log_file, i))
                else
                    log_i = nullfile()
                cr = callr::r_bg(function(m) clustermq:::worker(m),
                                 args=list(m=private$master),
                                 stdout=log_i, stderr=log_i)
                private$callr[[as.character(cr$get_pid())]] = cr
            }
            private$workers_total = n_jobs
        },

        cleanup = function(quiet=FALSE, timeout=3) {
            dead_workers = sapply(private$callr, function(x) ! x$is_alive())
            if (length(dead_workers) > 0)
                private$callr[dead_workers] = NULL
        }
    ),

    private = list(
        callr = list(),

        finalize = function(quiet=FALSE) {
#            if (!private$is_cleaned_up) {
                dead_workers = sapply(private$callr, function(x) ! x$is_alive())
                if (length(dead_workers) > 0)
                    private$callr[dead_workers] = NULL
                if (!quiet && length(private$callr) > 0)
                    warning("Unclean shutdown for PIDs: ",
                            paste(names(private$callr), collapse=", "), immediate.=TRUE)
                for (cr in private$callr)
                    cr$kill_tree()
#                private$is_cleaned_up = TRUE
#            }
        }
    )
)
