#' Placeholder for local processing
#'
#' Mainly so tests pass without setting up a scheduler
LOCAL = R6::R6Class("LOCAL",
    inherit = QSys,

    public = list(
        initialize = function(fun, const, export, seed) {
            super$initialize()
            private$set_common_data(fun=fun, const=const, export=export, seed=seed)
        },

        submit_job = function(scheduler_args=list(), log_worker=FALSE) {
        },

        cleanup = function(dirty=FALSE) {
        }
    )
)
