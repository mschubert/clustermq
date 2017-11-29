#' Process on multiple cores on one machine
#'
#' This makes use of rzmq messaging and sends requests via TCP/IP
MULTICORE = R6::R6Class("MULTICORE",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(..., node="localhost")
        },

        submit_jobs = function(n_jobs, template=list(), log_worker=FALSE) {
#            # create cluster and start worker on every node
#            private$cluster = parallel::makeCluster(n_jobs)
#            parallel::clusterCall(cl = private$cluster,
#                                  fun = clustermq:::worker,
#                                  master = values$master)

            cmd = quote(clustermq:::worker(private$master, verbose=FALSE))
            for (i in seq_len(n_jobs)) {
                p = parallel::mcparallel(cmd, silent=TRUE, detached=TRUE)
                private$pids = c(private$pids, p$pid)
            }
            private$workers_total = n_jobs
        },

        cleanup = function(dirty=FALSE) {
            super$cleanup()

            if (self$workers_running > 0)
                tools::pskill(private$pids, tools::SIGKILL)

#            parallel::stopCluster(private$cluster)
        }
    ),

    private = list(
        pids = NULL
#        cluster = NULL
    )
)
