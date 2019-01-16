#' Placeholder for local processing
#'
#' Mainly so tests pass without setting up a scheduler
#'
#' @keywords internal
LOCAL = R6::R6Class("LOCAL",
    inherit = QSys,

    public = list(
        initialize = function(..., data=NULL) {
            super$initialize(..., data=data)
        },

        set_common_data = function(...) {
        },

        submit_jobs = function(...) {
        },

        cleanup = function(quiet=FALSE, timeout=3) {
            invisible(TRUE)
        }
    )
)
