#' PBS/Torque scheduler functions
#'
#' Derives from QSys to provide PBS/Torque-specific functions
PBS = R6::R6Class("PBS",
    inherit = SGE,

    public = list(
        initialize = function(...) {
            super$initialize(...)
        }
    )
)

# Static method, process scheduler options and return updated object
PBS$setup = function() {
    user_template = getOption("clustermq.template.pbs")
    if (!is.null(user_template)) {
        warning("scheduler-specific templates are deprecated; use clustermq.template instead")
        PBS$template = readChar(user_template, file.info(user_template)$size)
    }
    user_template = getOption("clustermq.template")
    if (!is.null(user_template))
        PBS$template = readChar(user_template, file.info(user_template)$size)

    user_defaults = getOption("clustermq.defaults")
    if (!is.null(user_defaults))
        PBS$defaults = user_defaults
    else
        PBS$defaults = list()

    PBS
}

# Static method, overwritten in qsys w/ user option
PBS$template = paste(sep="\n",
    "#PBS -N {{ job_name }}",
    "#PBS -l nodes={{ n_jobs }}:ppn=1",
    "#PBS -o {{ log_file | /dev/null }}",
    "#PBS -j oe",
    "",
    "ulimit -v $(( 1024 * {{ memory | 4096 }} ))",
    "R --no-save --no-restore -e 'clustermq:::worker(\"{{ master }}\")'")
