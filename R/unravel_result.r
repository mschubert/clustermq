#' Separate out warnings and errors from result
#'
#' @param robj  A list with fields 'result' and 'warnings'
#' @param at    How many calls were procesed  up to this point
#' @param fail_on_error  Stop if error(s) occurred
unravel_result = function(robj, at=length(robj$result), fail_on_error=TRUE) {
    # register all job warnings as summary
    if (length(robj$warnings) > 0) {
        summ = sprintf("%i warnings occurred in processing", length(robj$warnings))
        warning(paste(c(list(summ), robj$warnings), collapse="\n"))
    }

    # check for failed jobs, report which and how many failed
    failed = which(sapply(robj$result, class) == "error")
    if (any(failed)) {
        msg = sprintf("%i/%i jobs failed.", length(failed), at)
        if (fail_on_error)
            stop(msg, " Stopping.")
        else
            warning(msg, immediate.=TRUE)
    }

    unname(robj$result)
}
