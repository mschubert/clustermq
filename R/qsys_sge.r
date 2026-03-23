
#' SGE scheduler functions
#'
#' Derives from QSys to provide SGE-specific functions
#'
#' @keywords internal
SGE = R6::R6Class("SGE",
    inherit = QSys,

    public = list(
        initialize = function(addr, n_jobs, master, ..., template=getOption("clustermq.template", "SGE"),
                              log_worker=FALSE, log_file=NULL, verbose=TRUE) {
            super$initialize(addr=addr, master=master, template=template)

            opts = private$fill_options(n_jobs=n_jobs, ...)
            private$job_name = opts$job_name
            if (!is.null(opts$log_file))
                opts$log_file = normalizePath(opts$log_file, mustWork=FALSE)
            else if (log_worker)
                opts$log_file = sprintf("%s-%s.log", private$job_name, private$array_idx)
            filled = fill_template(private$template, opts, required=c("master", "n_jobs"))

            if (verbose)
                message("Submitting ", n_jobs, " worker jobs to ", class(self)[1],
                        " as ", sQuote(private$job_id), " ...")

            private$qsub_stdout = system2("qsub", input=filled, stdout=TRUE)
            status = attr(private$qsub_stdout, "status")
            if (!is.null(status) && status != 0)
                private$template_error("SGE", status, filled)
            private$job_id = private$job_name
            private$master$add_pending_workers(n_jobs)
            private$is_cleaned_up = FALSE
        },

        cleanup = function(success, timeout) {
            private$is_cleaned_up = success
            private$finalize()
        }
    ),

    private = list(
        qsub_stdout = NULL,
        job_name = NULL,
        job_id   = NULL,
        array_idx = "$TASK_ID",

        finalize = function(quiet = TRUE) { # self$workers_running == 0
            if (!private$is_cleaned_up) {
                system(paste("qdel", private$job_id),
                       ignore.stdout=quiet, ignore.stderr=quiet, wait=FALSE)
            }
            private$is_cleaned_up = TRUE
        }
    ),

    cloneable = FALSE
)

#' Class for Open Cluster Scheduler (OCS)
OCS = R6::R6Class("OCS",
    inherit = QSys,

    public = list(
        initialize = function(addr, n_jobs, master, ..., template=getOption("clustermq.template", class(self)[1]),
                              log_worker=FALSE, log_file=NULL, verbose=TRUE) {
            super$initialize(addr=addr, master=master, template=template)

            opts = private$fill_options(n_jobs=n_jobs, ...)
            filled = fill_template(private$template, opts, required=c("master", "n_jobs"))
            qsub_stdout = system2("qsub", input=filled, stdout=TRUE)

            status = attr(qsub_stdout, "status")
            if (!is.null(status) && status != 0)
                private$template_error(class(self)[1], status, filled)

            private$job_id = regmatches(qsub_stdout, regexpr("^[0-9]+", qsub_stdout))
            if (length(private$job_id) == 0)
                private$template_error(class(self)[1], qsub_stdout, filled)

            if (verbose)
                message("Submitted ", n_jobs, " worker tasks to ", class(self)[1], " as array job ", private$job_id, " ...")

            private$master$add_pending_workers(n_jobs)
        },

        cleanup = function(success, timeout) {
            system(paste("qdel", private$job_id), ignore.stdout=TRUE, ignore.stderr=TRUE, wait=FALSE)
        }
    ),

    private = list(
        job_id   = NULL
    ),

    cloneable = FALSE
)

#' Class for Gridware Cluster Scheduler (GCS)
GCS = R6::R6Class("GCS",
    inherit = OCS,
    cloneable = FALSE

    # no changes needed, but we want to have a separate class for GCS to allow for GCS-specific
    # templates and enterprise edition options
)

PBS = R6::R6Class("PBS",
    inherit = SGE,

    public = list(
        initialize = function(..., template=getOption("clustermq.template", "PBS")) {
            super$initialize(..., template=template)
            private$array_idx = "$PBS_ARRAY_INDEX"
            private$job_id = private$qsub_stdout[1]
        }
    ),

    cloneable = FALSE
)

TORQUE = R6::R6Class("TORQUE",
    inherit = PBS,

    public = list(
        initialize = function(..., template=getOption("clustermq.template", "TORQUE")) {
            super$initialize(..., template=template)
            private$array_idx = "$PBS_ARRAYID"
        }
    ),

    cloneable = FALSE
)
