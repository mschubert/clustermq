#' SLURM scheduler functions
#'
#' Derives from QSys to provide SLURM-specific functions
#'
#' @keywords internal
SLURM = R6::R6Class("SLURM",
    inherit = QSys,

    public = list(
        initialize = function(..., template=getOption("clustermq.template", "SLURM")) {
            super$initialize(..., template=template)
        },

        submit_jobs = function(...) {
            opts = private$fill_options(...)
            private$job_id = opts$job_name
            filled = private$fill_template(opts)

            success = system("sbatch", input=filled, ignore.stdout=TRUE)
            if (success != 0) {
                print(filled)
                stop("Job submission failed with error code ", success)
            }
        },

        finalize = function(quiet = self$workers_running == 0) {
            if (!private$is_cleaned_up) {
                system(paste("scancel --name", private$job_id),
                       ignore.stdout=quiet, ignore.stderr=quiet, wait=FALSE)
                private$is_cleaned_up = TRUE
            }
        }
    ),

    private = list(
        job_id = NULL
    )
)
