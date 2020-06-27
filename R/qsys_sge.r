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

        submit_jobs = function(n_jobs, ..., log_worker=FALSE, verbose=TRUE) {
            opts = private$fill_options(n_jobs=n_jobs, ...)
            private$job_name = opts$job_name
            if (!is.null(opts$log_file))
                opts$log_file = normalizePath(opts$log_file, mustWork=FALSE)
            else if (log_worker)
                opts$log_file = sprintf("%s-%s.log", private$job_name, private$array_idx)
            filled = fill_template(private$template, opts,
                                   required=c("master", "n_jobs"))

            if (verbose)
                message("Submitting ", n_jobs, " worker jobs (ID: ", private$job_name, ") ...")

            qsub_stdout  = system2("qsub", input=filled, stdout=TRUE)
            status = attr(qsub_stdout, "status")
            success = (is.null(status) || (status == 0))

            if (!success) {
                print(filled)
                stop("Job submission failed with error code ", success)
            }

            private$set_job_id(qsub_stdout)
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
        job_id   = NULL,
        array_idx = "\\$TASK_ID",

        # This implementation of set_job_id ignores input argument qsub_stdout
        # as it can use job_name to refer to jobs in qdel
        set_job_id = function(qsub_stdout) private$job_id = private$job_name
    )
)

PBS = R6::R6Class("PBS",
    inherit = SGE,

    public = list(
        initialize = function(..., template=getOption("clustermq.template", "PBS")) {
            super$initialize(..., template=template)
            private$array_idx = "$PBS_ARRAY_INDEX"
        }
    ),

    private = list(
        set_job_id = function(qsub_stdout) private$job_id = qsub_stdout[1]
    )
)

TORQUE = R6::R6Class("TORQUE",
    inherit = PBS,

    public = list(
        initialize = function(..., template=getOption("clustermq.template", "TORQUE")) {
            super$initialize(..., template=template)
            private$array_idx = "$PBS_ARRAYID"
        }
    )
)
