#' SLURM scheduler functions
#'
#' Derives from QSys to provide SLURM-specific functions
SLURM = R6::R6Class("SLURM",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(...)
        },

        submit_job = function(template=list(), log_worker=FALSE) {
            values = super$submit_job(template=template, log_worker=log_worker)
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
    if (!is.null(user_template))
        SLURM$template = readChar(user_template, file.info(user_template)$size)
    SLURM
}

# Static method, overwritten in qsys w/ user option
SLURM$template = paste(sep="\n",
	"#SBATCH --job-name={{ job_name }}",
	"#SBATCH --output={{ log_file | /dev/null }}",
	"#SBATCH --error={{ log_file | /dev/null }}",
	"#SBATCH --mem-per-cpu={{ memory | 4096 }}",
    "",
    "ulimit -v $(( 1024 * {{ memory | 4096 }} ))",
    "R --no-save --no-restore -e \\",
    "    'clustermq:::worker(\"{{ job_name }}\", \"{{ master }}\", {{ memory | 4096 }})'")
