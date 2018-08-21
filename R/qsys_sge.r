#' SGE scheduler functions
#'
#' Derives from QSys to provide SGE-specific functions
SGE = R6::R6Class("SGE",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(..., template=getOption("clustermq.template", "SGE"))
        },

        submit_jobs = function(...) {
            opts = private$fill_options(...)
            private$job_id = opts$job_name
            filled = private$fill_template(opts)

            success = system("qsub", input=filled, ignore.stdout=TRUE)
            if (success != 0) {
                print(filled)
                stop("Job submission failed with error code ", success)
            }
        },

        finalize = function() {
            if (!private$is_cleaned_up) {
                system(paste("qdel", private$job_id),
                       ignore.stdout=FALSE, ignore.stderr=FALSE, wait=FALSE)
                private$is_cleaned_up = TRUE
            }
        }
    ),

    private = list(
        job_id = NULL
    )
)
