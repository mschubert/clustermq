#' Placeholder for local processing
#'
#' Mainly so tests pass without setting up a scheduler
#'
#' @keywords internal
LOCAL = R6::R6Class("LOCAL",
    inherit = QSys,

    public = list(
        initialize = function(addr="unused", n_jobs=0, ..., log_worker=FALSE,
                              log_file=NULL, verbose=TRUE) {
            super$initialize(addr=addr, ...)
            if (verbose)
                message("Running sequentially ('LOCAL') ...")
        },

        cleanup = function(quiet=FALSE, timeout=3) {
            invisible(TRUE)
        }
    )
)
