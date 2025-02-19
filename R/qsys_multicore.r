#' Process on multiple cores on one machine
#'
#' Derives from QSys to provide multicore-specific functions
#'
#' @keywords internal
MULTICORE = R6::R6Class("MULTICORE",
    inherit = QSys,

    public = list(
        initialize = function(addr, n_jobs, master, ..., log_worker=FALSE, log_file=NULL, verbose=TRUE) {
            addr = sub(Sys.info()["nodename"], "127.0.0.1", addr, fixed=TRUE)
            super$initialize(addr=addr, master=master)
            if (verbose)
                message("Starting ", n_jobs, " cores ...")
            if (log_worker && is.null(log_file))
                log_file = sprintf("cmq%i-%%i.log", private$port)

            for (i in seq_len(n_jobs)) {
                if (is.character(log_file))
                    log_i = suppressWarnings(sprintf(log_file, i))
                else
                    log_i = nullfile()
                wrapper = function(m, logfile) {
                    fout = file(logfile, open="wt")
                    sink(file=fout, type="output")
                    sink(file=fout, type="message")
                    on.exit({ sink(type="message"); sink(type="output"); close(fout) })
                    clustermq:::worker(m)
                }
                p = parallel::mcparallel(quote(wrapper(private$addr, log_i)))
                private$children[[as.character(p$pid)]] = p
            }
            private$master$add_pending_workers(n_jobs)
            private$workers_total = n_jobs
            private$is_cleaned_up = FALSE
        },

        cleanup = function(success, timeout=5L) {
            private$is_cleaned_up = success
            private$collect_children(wait=FALSE, timeout=timeout)
            private$finalize()
        }
    ),

    private = list(
        collect_children = function(...) {
            pids = as.integer(names(private$children))
            res = suppressWarnings(parallel::mccollect(pids, ...))
            finished = intersect(names(private$children), names(res))
            private$children[finished] = NULL
        },

        children = list(),

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
                private$children = list()
            }
            private$is_cleaned_up = TRUE
        }
    ),

    cloneable = FALSE
)
