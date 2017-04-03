#' SLURM scheduler functions
#'
#' Derives from QSys to provide SLURM-specific functions
SLURM = R6::R6Class("SLURM",
    inherit = QSys,

    public = list(
        initialize = function(fun, const, seed) {
            super$initialize()
            private$set_common_data(fun=fun, const=const, seed=seed)
        },

        submit_job = function(memory=NULL, walltime=NA, log_worker=FALSE) {
            values = super$submit_job(memory=memory, walltime=NA, log_worker=log_worker)
            job_input = infuser::infuse(SLURM$template, values)
            system("sbatch", input=job_input, ignore.stdout=TRUE)
        },

        cleanup = function(dirty=FALSE) {
            if (dirty)
                warning("Jobs may not have shut down properly")
        }
    ),
)

# Static method, process scheduler options and return updated object
SLURM$setup = function() {
    user_template = getOption("clustermq.template.slurm")
    if (length(user_template) == 0) {
        message("* Option 'clustermq.template.slurm' not set, ",
                "defaulting to package template")
        message("--- see: https://github.com/mschubert/clustermq/wiki/SLURM")
    } else {
        SLURM$template = readChar(user_template, file.info(user_template)$size)
    }
    SLURM
}

# Static method, overwritten in qsys w/ user option
SLURM$template = paste(sep="\n",
	"#SBATCH --job-name={{ job_name }}",
	"#SBATCH --output={{ log_file | /dev/null }}",
	"#SBATCH --error={{ log_file | /dev/null }}",
	"#SBATCH --mem-per-cpu={{ memory | 4096 }}",
    "",
    "R --no-save --no-restore -e \\",
    "    'clustermq:::worker(\"{{ job_name }}\", \"{{ master }}\", {{ memory }})'")
