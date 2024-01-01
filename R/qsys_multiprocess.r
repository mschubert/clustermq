#' Process on multiple processes on one machine
#'
#' Derives from QSys to provide callr-specific functions
#'
#' @keywords internal
MULTIPROCESS = R6::R6Class("MULTIPROCESS",
    inherit = QSys,

    public = list(
        initialize = function(addr, n_jobs, master, ..., log_worker=FALSE, log_file=NULL, verbose=TRUE) {
            if (! requireNamespace("callr", quietly=TRUE))
                stop("The ", sQuote(callr), " package is required for ", sQuote("multiprocess"))
            addr = sub(Sys.info()["nodename"], "127.0.0.1", addr, fixed=TRUE)
            super$initialize(addr=addr, master=master)

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
                                 args=list(m=private$addr),
                                 stdout=log_i, stderr=log_i)
                private$callr[[as.character(cr$get_pid())]] = cr
            }
            private$master$add_pending_workers(n_jobs)
            private$workers_total = n_jobs
            private$is_cleaned_up = FALSE
        },

        cleanup = function(success, timeout) {
            dead_workers = sapply(private$callr, function(x) ! x$is_alive())
            if (length(dead_workers) > 0)
                private$callr[dead_workers] = NULL
            else
                private$is_cleaned_up = TRUE
            private$is_cleaned_up
        }
    ),

    private = list(
        callr = list(),

        finalize = function(quiet=FALSE) {
            if (!private$is_cleaned_up) {
                dead_workers = sapply(private$callr, function(x) ! x$is_alive())
                if (length(dead_workers) > 0)
                    private$callr[dead_workers] = NULL
                if (!quiet && length(private$callr) > 0)
                    warning("Unclean shutdown for PIDs: ",
                            paste(names(private$callr), collapse=", "), immediate.=TRUE)
                for (cr in private$callr)
                    cr$kill_tree()
            }
            private$is_cleaned_up = TRUE
        }
    )
)
