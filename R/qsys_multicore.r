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
            values = super$submit_jobs(template=template, log_worker=log_worker)

#            # create cluster and start worker on every node
#            private$cluster = parallel::makeCluster(n_jobs)
#            parallel::clusterCall(cl = private$cluster,
#                                  fun = clustermq:::worker,
#                                  worker_id = values$job_name,
#                                  master = values$master,
#                                  memlimit = values$memory)

            cmd = Quote(clustermq:::worker(values$master))
            for (i in seq_len(n_jobs))
                parallel::mcparallel(cmd)
        },

        cleanup = function(dirty=FALSE) {
            super$cleanup()
#            parallel::stopCluster(private$cluster)
        }
    ),

    private = list(
#        cluster = NULL
    )
)
