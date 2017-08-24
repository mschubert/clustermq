#' Separate out warnings and errors from result
#'
#' @param robj  A list with fields 'result' and 'warnings'
#' @param at    How many calls were procesed  up to this point
#' @param fail_on_error  Stop if error(s) occurred
unravel_result = function(robj, at=length(robj$result), fail_on_error=TRUE) {
    # check for failed jobs, report which and how many failed
    failed = which(sapply(robj$result, class) == "error")
    n_warns = length(robj$warnings)

    if (any(failed)) {
        msg = sprintf("%i/%i jobs failed (%i warnings)", length(failed), at, n_warns)
        detail = unlist(c(utils::head(robj$result[failed], 50),
                          utils::head(robj$warnings, 50)))
        idx = gsub("[^\\d]+", "", gsub(").*$", "", detail), perl=TRUE)
        detail = paste(detail[as.integer(order(idx))], collapse="\n")
        if (fail_on_error)
            stop(msg, ". Stopping.\n", detail)
        else
            warning(msg, "\n", detail, immediate.=TRUE)
    } else if (length(robj$warnings) > 0) {
        msg = sprintf("%i warnings occurred in processing\n", length(robj$warnings))
        warning(msg, paste(robj$warnings, collapse="\n"), immediate.=TRUE)
    }

    unname(robj$result)
}
