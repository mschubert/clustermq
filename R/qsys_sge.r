#' SGE scheduler functions
#'
#' Derives from QSys to provide SGE-specific functions
#'
#' @keywords internal
SGE = R6::R6Class("SGE",
    inherit = QSys,

    public = list(
        initialize = function(..., template=getOption("clustermq.template", "SGE")) {
            super$initialize(..., template=template)
        },

        submit_jobs = function(...) {
            opts = private$fill_options(...)
            private$job_name = opts$job_name
            filled = private$fill_template(opts)

            output  = system2("qsub", input=filled, stdout = T)
            
            status = attr(output, "status")
            success = (!length(status)) || (status != 0)
            
            if (!success) {
                print(filled)
                stop("Job submission failed with error code ", success)
            }
            # The first thing printed to stdout by qsub is the id
            private$job_id = output[1]
        },

        finalize = function(quiet=self$workers_running == 0) {
            if (!private$is_cleaned_up) {
                system(paste("qdel", private$job_id),
                       ignore.stdout=quiet, ignore.stderr=quiet, wait=FALSE)
                private$is_cleaned_up = TRUE
            }
        }
    ),

    private = list(
        job_name = NULL,
        job_id   = NULL
    )
)

PBS = R6::R6Class("PBS",
    inherit = SGE,

    public = list(
        initialize = function(..., template=getOption("clustermq.template", "PBS")) {
            super$initialize(..., template=template)
        }
    )
)

TORQUE = R6::R6Class("TORQUE",
    inherit = SGE,

    public = list(
        initialize = function(..., template=getOption("clustermq.template", "TORQUE")) {
            super$initialize(..., template=template)
        }
    )
)
