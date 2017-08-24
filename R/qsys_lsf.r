#' LSF scheduler functions
#'
#' Derives from QSys to provide LSF-specific functions
LSF = R6::R6Class("LSF",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(...)
        },

        submit_job = function(template=list(), log_worker=FALSE) {
            values = super$submit_job(template=template, log_worker=log_worker)
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
    if (!is.null(user_template))
        LSF$template = readChar(user_template, file.info(user_template)$size)
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
    "ulimit -v $(( 1024 * {{ memory | 4096 }} ))",
    "R --no-save --no-restore -e \\",
    "    'clustermq:::worker(\"{{ job_name }}\", \"{{ master }}\", {{ memory | 4096 }})'")
