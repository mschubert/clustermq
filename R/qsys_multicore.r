#' Process on multiple cores on one machine
#'
#' This makes use of rzmq messaging and sends requests via TCP/IP
MULTICORE = R6::R6Class("MULTICORE",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(..., node="localhost")
        },

        submit_job = function(template=list(), log_worker=FALSE) {
            values = super$submit_job(template=template, log_worker=log_worker)
#            job_input = infuser::infuse(MULTICORE$template, values)
#            system(job_input, wait=FALSE)
#            #TODO: get pid, put in list, clean up in the end
            cmd = Quote(clustermq:::worker(values$job_name, values$master, values$memory))
            parallel::mcparallel(cmd)
        },

        cleanup = function(dirty=FALSE) {
            super$cleanup()
            #TODO: kill the processes here if still running
        }
    )
)

MULTICORE$template = paste(sep="\n",
    "ulimit -v $(( 1024 * {{ memory | 4096 }} ))",
    "R --no-save --no-restore -e \\",
    "    'clustermq:::worker(\"{{ job_name }}\", \"{{ master }}\", {{ memory | 4096 }})' > {{ log_file | /dev/null }} 2>&1")
