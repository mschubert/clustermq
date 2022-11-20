#' Placeholder for local processing
#'
#' Mainly so tests pass without setting up a scheduler
#'
#' @keywords internal
LOCAL = R6::R6Class("LOCAL",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(...)
        },

        submit_jobs = function(..., verbose=TRUE) {
            if (verbose)
                message("Running sequentially ('LOCAL') ...")
        },

        cleanup = function(quiet=FALSE, timeout=3) {
            invisible(TRUE)
        }
    )
)
