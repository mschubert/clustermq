#' LSF scheduler functions
#'
#' Derives from QSys to provide LSF-specific functions
#'
#' @keywords internal
LSF = R6::R6Class("LSF",
    inherit = QSys,

    public = list(
        initialize = function(..., template=getOption("clustermq.template", "LSF")) {
            super$initialize(..., template=template)
        },

        submit_jobs = function(n_jobs, ..., log_worker=FALSE, verbose=TRUE) {
            opts = private$fill_options(n_jobs=n_jobs, ...)
            private$job_id = opts$job_name
            if (!is.null(opts$log_file))
                opts$log_file = normalizePath(opts$log_file, mustWork=FALSE)
            else if (log_worker)
                opts$log_file = paste0(private$job_id, "-%I.log")
            filled = fill_template(private$template, opts,
                                   required=c("master", "job_name", "n_jobs"))

            if (verbose)
                message("Submitting ", n_jobs, " worker jobs (ID: ", private$job_id, ") ...")

            success = system("bsub", input=filled, ignore.stdout=TRUE)
            if (success != 0) {
                print(filled)
                stop("Job submission failed with error code ", success)
            }
        },

        finalize = function(quiet=self$workers_running == 0) {
            if (!private$is_cleaned_up) {
                system(paste("bkill -J", private$job_id),
                       ignore.stdout=quiet, ignore.stderr=quiet, wait=FALSE)
                private$is_cleaned_up = TRUE
            }
        }
    ),

    private = list(
        job_id = NULL
    )
)
