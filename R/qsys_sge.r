#' SGE scheduler functions
#'
#' Derives from QSys to provide SGE-specific functions
SGE = R6::R6Class("SGE",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(..., template=getOption("clustermq.template",
                system.file("SGE.tmpl", package="clustermq", mustWork=TRUE)))
        },

        submit_jobs = function(n_jobs, ...) {
            args = list(n_jobs=n_jobs, ...)
            private$job_id = args$job_name
            filled = do.call(private$fill_template, args)

            success = system("qsub", input=filled, ignore.stdout=TRUE)
            if (success != 0) {
                print(filled)
                stop("Job submission failed with error code ", success)
            }
            private$workers_total = n_jobs
        },

        cleanup = function() {
            success = super$cleanup()
            self$finalize(success)
        },

        finalize = function(clean=FALSE) {
            if (!private$is_cleaned_up) {
                system(paste("qdel", private$job_id),
                       ignore.stdout=clean, ignore.stderr=clean)
                private$is_cleaned_up = TRUE
            }
        }
    ),

    private = list(
        template = "",
        defaults = list(),
        is_cleaned_up = FALSE,
        job_id = NULL
    )
)
