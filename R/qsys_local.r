#' Placeholder for local processing
#'
#' Mainly so tests pass without setting up a scheduler
LOCAL = R6::R6Class("LOCAL",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(...)
        },

        submit_job = function(template=list(), log_worker=FALSE) {
        },

        cleanup = function(dirty=FALSE) {
        }
    )
)
