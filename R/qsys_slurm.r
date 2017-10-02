#' SLURM scheduler functions
#'
#' Derives from QSys to provide SLURM-specific functions
SLURM = R6::R6Class("SLURM",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(...)
        },

        submit_jobs = function(n_jobs, template=list(), log_worker=FALSE) {
            template$n_jobs = n_jobs
            filled = fill_template(template=SLURM$template, master=private$master,
                                   values=template, log_worker=log_worker)

            success = system("sbatch", input=filled, ignore.stdout=TRUE)
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
SLURM$setup = function() {
    user_template = getOption("clustermq.template.slurm")
    if (!is.null(user_template))
        SLURM$template = readChar(user_template, file.info(user_template)$size)
    SLURM
}

# Static method, overwritten in qsys w/ user option
SLURM$template = paste(sep="\n",
    "#!/bin/sh",
    "#SBATCH --job-name={{ job_name }}",
    "#SBATCH --output={{ log_file | /dev/null }}",
    "#SBATCH --error={{ log_file | /dev/null }}",
    "#SBATCH --mem-per-cpu={{ memory | 4096 }}",
    "#SBATCH --array=1-{{ n_jobs }}",
    "",
    "ulimit -v $(( 1024 * {{ memory | 4096 }} ))",
    "R --no-save --no-restore -e 'clustermq:::worker(\"{{ master }}\"')")
