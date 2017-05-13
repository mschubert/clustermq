#' LSF scheduler functions
#'
#' Derives from QSys to provide LSF-specific functions
LSF = R6::R6Class("LSF",
    inherit = QSys,

    public = list(
        initialize = function(fun, const, seed) {
            super$initialize()
            private$set_common_data(fun=fun, const=const, seed=seed)
        },

        submit_job = function(scheduler_args=list(), log_worker=FALSE) {
            values = super$submit_job(scheduler_args=scheduler_args, log_worker=log_worker)
            job_input = infuser::infuse(LSF$template, values)
            system("bsub", input=job_input, ignore.stdout=TRUE)
        },

        cleanup = function(dirty=FALSE) {
            system(paste("bkill -g", private$job_group, "0"),
                   ignore.stdout=!dirty, ignore.stderr=!dirty)
        }
    ),
)

# Static method, process scheduler options and return updated object
LSF$setup = function() {
    user_template = getOption("clustermq.template.lsf")
    if (length(user_template) == 0) {
        message("* Option 'clustermq.template.lsf' not set, ",
                "defaulting to package template")
        message("--- see: https://github.com/mschubert/clustermq/wiki/LSF")
    } else {
        LSF$template = readChar(user_template, file.info(user_template)$size)
    }
    LSF
}

# Static method, overwritten in qsys w/ user option
LSF$template = paste(sep="\n",
    "#BSUB-J {{ job_name }}                    # name of the job / array jobs",
    "#BSUB-g {{ job_group | /rzmq }}           # group the job belongs to",
    "#BSUB-o {{ log_file | /dev/null }}        # stdout + stderr",
    "#BSUB-M {{ memory | 4096 }}               # Memory requirements in Mbytes",
    "#BSUB-R rusage[mem={{ memory | 4096  }}]  # Memory requirements in Mbytes",
    "",
    "R --no-save --no-restore -e \\",
    "    'clustermq:::worker(\"{{ job_name }}\", \"{{ master }}\", {{ memory | 4096 }})'")
