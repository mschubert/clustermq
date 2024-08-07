#' SLURM scheduler functions
#'
#' Derives from QSys to provide SLURM-specific functions
#'
#' @keywords internal
SLURM = R6::R6Class("SLURM",
    inherit = QSys,

    public = list(
        initialize = function(addr, n_jobs, master, ..., template=getOption("clustermq.template", "SLURM"),
                              log_worker=FALSE, verbose=TRUE) {
            super$initialize(addr=addr, master=master, template=template)

            opts = private$fill_options(n_jobs=n_jobs, ...)
            private$job_id = opts$job_name
            if (!is.null(opts$log_file))
                opts$log_file = normalizePath(opts$log_file, mustWork=FALSE)
            else if (log_worker)
                opts$log_file = paste0(private$job_id, "-%a.log")
            filled = fill_template(private$template, opts,
                                   required=c("master", "job_name", "n_jobs"))

            if (verbose)
                message("Submitting ", n_jobs, " worker jobs to ", class(self)[1],
						" (ID: ", private$job_id, ") ...")

            status = system("sbatch", input=filled, ignore.stdout=TRUE)
            if (status != 0)
                private$template_error("SLURM", status, filled)
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

        finalize = function(quiet = TRUE) { # self$workers_running == 0
            if (!private$is_cleaned_up) {
                system(paste("scancel --name", private$job_id),
                       ignore.stdout=quiet, ignore.stderr=quiet, wait=FALSE)
            }
            private$is_cleaned_up = TRUE
        }
    )
)
