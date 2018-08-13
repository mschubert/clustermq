#' LSF scheduler functions
#'
#' Derives from QSys to provide LSF-specific functions
LSF = R6::R6Class("LSF",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(..., template=getOption("clustermq.template", "LSF"))
        },

        submit_jobs = function(...) {
            opts = private$fill_options(...)
            private$job_id = opts$job_name
            filled = private$fill_template(opts)

            success = system("bsub", input=filled, ignore.stdout=TRUE)
            if (success != 0) {
                print(filled)
                stop("Job submission failed with error code ", success)
            }
        },

        finalize = function() {
            if (!private$is_cleaned_up) {
                system(paste("bkill -J", private$job_id),
                       ignore.stdout=FALSE, ignore.stderr=clean)
                private$is_cleaned_up = TRUE
            }
        }
    ),

    private = list(
        job_id = NULL
    )
)
