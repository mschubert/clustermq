#' SGE scheduler functions
#'
#' Derives from QSys to provide SGE-specific functions
SGE = R6::R6Class("SGE",
    inherit = QSys,

    public = list(
        initialize = function(fun, const, seed) {
            super$initialize()
            private$set_common_data(fun=fun, const=const, seed=seed)
        },

        submit_job = function(scheduler_args=list(), log_worker=FALSE) {
            values = super$submit_job(scheduler_args=scheduler_args, log_worker=log_worker)
            job_input = infuser::infuse(SGE$template, values)
            system("qsub", input=job_input, ignore.stdout=TRUE)
        },

        cleanup = function(dirty=FALSE) {
            if (dirty)
                warning("Jobs may not have shut down properly")
        }
    ),
)

# Static method, process scheduler options and return updated object
SGE$setup = function() {
    user_template = getOption("clustermq.template.sge")
    if (length(user_template) == 0) {
        message("* Option 'clustermq.template.sge' not set, ",
                "defaulting to package template")
        message("--- see: https://github.com/mschubert/clustermq/wiki/SGE")
    } else {
        SGE$template = readChar(user_template, file.info(user_template)$size)
    }
    SGE
}

# Static method, overwritten in qsys w/ user option
SGE$template = paste(sep="\n",
    "#$ -N {{ job_name }}               # job name",
    "#$ -j y                            # combine stdout/error in one file",
    "#$ -o {{ log_file | /dev/null }}   # output file",
    "#$ -cwd                            # use pwd as work dir",
    "#$ -V                              # use environment variable",
    "",
    "R --no-save --no-restore -e \\",
    "    'clustermq:::worker(\"{{ job_name }}\", \"{{ master }}\", {{ memory | 4096 }})'")
