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
            filled = fill_template(template=SGE$template, master=private$master,
                                   values=template, log_worker=log_worker)

            success = system("qsub", input=filled, ignore.stdout=TRUE)
            if (success != 0) {
                print(filled)
                stop("Job submission failed with error code ", success)
            }
        },

        cleanup = function() {
            super$cleanup()
            if (self$workers_running > 0)
                warning("Jobs may not have shut down properly")
        }
    ),
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
