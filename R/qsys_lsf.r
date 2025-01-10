#' LSF scheduler functions
#'
#' Derives from QSys to provide LSF-specific functions
#'
#' @keywords internal
LSF = R6::R6Class("LSF",
    inherit = QSys,

    public = list(
        initialize = function(addr, n_jobs, master, ..., template=getOption("clustermq.template", "LSF"),
                              log_worker=FALSE, log_file=NULL, verbose=TRUE) {
            super$initialize(addr=addr, master=master, template=template)

            opts = private$fill_options(n_jobs=n_jobs, ...)
            private$job_id = opts$job_name
            if (!is.null(opts$log_file))
                opts$log_file = normalizePath(opts$log_file, mustWork=FALSE)
            else if (log_worker)
                opts$log_file = paste0(private$job_id, "-%I.log")
            filled = fill_template(private$template, opts,
                                   required=c("master", "job_name", "n_jobs"))

            if (verbose)
                message("Submitting ", n_jobs, " worker jobs to ", class(self)[1],
                        " as ", sQuote(private$job_id), " ...")

            status = system("bsub", input=filled, ignore.stdout=TRUE)
            if (status != 0)
                private$template_error("LSF", status, filled)
            private$master$add_pending_workers(n_jobs)
            private$is_cleaned_up = FALSE
        },

        cleanup = function(success, timeout) {
            private$is_cleaned_up = success
            private$finalize()
        }
    ),

    private = list(
        job_id = NULL,

        finalize = function(quiet=self$workers_running == 0) {
            quiet = FALSE #TODO:
            if (!private$is_cleaned_up) {
                system(paste("bkill -J", private$job_id),
                       ignore.stdout=quiet, ignore.stderr=quiet, wait=FALSE)
            }
            private$is_cleaned_up = TRUE
        }
    )
)
