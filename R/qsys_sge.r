#' SGE scheduler functions
#'
#' Derives from QSys to provide SGE-specific functions
SGE = R6::R6Class("SGE",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(...)
        },

        submit_jobs = function(n_jobs, template=list(), log_worker=FALSE) {
            template$n_jobs = n_jobs
            template$master = private$master
            private$job_id = template$job_name = paste0("cmq", self$id)
            if (log_worker)
                template$log_file = paste0(template$job_name, ".log")

            filled = infuser::infuse(SGE$template, template)

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
        is_cleaned_up = FALSE,
        job_id = NULL
    )
)

# Static method, process scheduler options and return updated object
SGE$setup = function() {
    user_template = getOption("clustermq.template.sge")
    if (!is.null(user_template))
        SGE$template = readChar(user_template, file.info(user_template)$size)
    SGE
}

# Static method, overwritten in qsys w/ user option
SGE$template = paste(sep="\n",
    "#$ -N {{ job_name }}               # job name",
    "#$ -j y                            # combine stdout/error in one file",
    "#$ -o {{ log_file | /dev/null }}   # output file",
    "#$ -cwd                            # use pwd as work dir",
    "#$ -V                              # use environment variable",
    "#$ -t 1-{{ n_jobs }}               # submit jobs as array",
    "",
    "ulimit -v $(( 1024 * {{ memory | 4096 }} ))",
    "R --no-save --no-restore -e 'clustermq:::worker(\"{{ master }}\")'")
