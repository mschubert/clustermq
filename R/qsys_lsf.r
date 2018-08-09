#' LSF scheduler functions
#'
#' Derives from QSys to provide LSF-specific functions
LSF = R6::R6Class("LSF",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(..., template=getOption("clustermq.template",
                system.file("LSF.tmpl", package="clustermq", mustWork=TRUE)))
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

        cleanup = function() {
            success = super$cleanup()
            self$finalize(success)
        },

        finalize = function(clean=FALSE) {
            if (!private$is_cleaned_up) {
                system(paste("bkill -J", private$job_id),
                       ignore.stdout=clean, ignore.stderr=clean)
                private$is_cleaned_up = TRUE
            }
        }
    ),

    private = list(
        is_cleaned_up = FALSE,
        job_id = NULL
    )
)
