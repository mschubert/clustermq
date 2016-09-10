#' LSF scheduler functions
#'
#' Derives from QSys to provide LSF-specific functions
LSF = R6::R6Class("LSF",
    inherit = QSys,

    public = list(
        initialize = function(fun, const, seed) {
            super$initialize()
            private$set_common_data(fun, const, seed)
            private$listen_socket(6000, 8000) # provides port, master
        },

        submit_job = function(memory=NULL, log_worker=FALSE) {
            if (is.null(private$master))
                stop("Need to call listen_socket() first")

            values = list(
                job_name = paste0("rzmq", private$port, "-", private$job_num),
                job_group = paste("/rzmq", private$port, sep="/"),
                master = private$master,
                memory = memory
            )

            private$job_group = values$job_group
            private$job_num = private$job_num + 1

            if (log_worker)
                values$log_file = paste0(values$job_name, ".log")

            job_input = infuser::infuse(LSF$template, values)
            system("bsub", input=job_input, ignore.stdout=TRUE)
        },

        cleanup = function() {
            system(paste("bkill -g", private$job_group, "0"), ignore.stdout=FALSE)
        }
    ),

    private = list(
        job_group = NULL
    ),

    cloneable=FALSE
)

# Static method, overwritten in qsys w/ user option
LSF$template = paste(sep="\n",
    "#BSUB-J {{ job_name }}                    # name of the job / array jobs",
    "#BSUB-g {{ job_group | /rzmq }}           # group the job belongs to",
    "#BSUB-o {{ log_file | /dev/null }}        # stdout + stderr",
    "#BSUB-M {{ memory | 4096 }}               # Memory requirements in Mbytes",
    "#BSUB-R rusage[mem={{ memory | 4096  }}]  # Memory requirements in Mbytes",
    "",
    "R --no-save --no-restore -e \\",
    "    'clustermq:::worker(\"{{ job_name }}\", \"{{ master }}\", {{ memory }})'")
