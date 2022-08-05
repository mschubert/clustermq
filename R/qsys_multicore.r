#' Process on multiple cores on one machine
#'
#' Derives from QSys to provide multicore-specific functions
#'
#' @keywords internal
MULTICORE = R6::R6Class("MULTICORE",
    inherit = QSys,

    public = list(
        initialize = function(addr=host("127.0.0.1"), ...) {
            super$initialize(addr=addr, ...)
        },

        submit_jobs = function(n_jobs, ..., log_worker=FALSE, log_file=NULL, verbose=TRUE) {
            if (verbose)
                message("Starting ", n_jobs, " cores ...")

            if (log_worker && is.null(log_file))
                log_file = "cmq-%i.log"

            for (i in seq_len(n_jobs)) {
                if (is.character(log_file))
                    log_i = sprintf(log_file, i)
                else
                    log_i = NULL
                wrapper = function(m, logfile) {
                    if (is.null(logfile))
                        logfile = "/dev/null"
                    fout = file(logfile, open="wt")
                    sink(file=fout, type="output")
                    sink(file=fout, type="message")
                    on.exit({ sink(type="message"); sink(type="output"); close(fout) })
                    clustermq:::worker(m)
                }
                p = parallel::mcparallel(quote(wrapper(private$master, log_i)))
                private$children[[as.character(p$pid)]] = p
            }
            private$workers_total = n_jobs
        },

        cleanup = function(quiet=FALSE, timeout=3) {
            success = super$cleanup(quiet=quiet, timeout=timeout)
            private$collect_children(wait=success, timeout=timeout)
            invisible(success && length(private$children) == 0)
        },

        finalize = function(quiet=FALSE) {
            if (!private$is_cleaned_up) {
                private$collect_children(wait=FALSE, timeout=0)
                running = names(private$children)
                if (length(running) > 0) {
                    if (!quiet)
                        warning("Unclean shutdown for PIDs: ",
                                paste(running, collapse=", "),
                                immediate.=TRUE)
                    tools::pskill(running, tools::SIGKILL)
                }
                private$is_cleaned_up = TRUE
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
