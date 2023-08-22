#' Print a summary of errors and warnings that occurred during processing
#'
#' @param result      A list or vector of the processing result
#' @param n_errors    How many errors occurred
#' @param n_warnings  How many warnings occurred
#' @param cond_msgs   Error and warnings messages, we display first 50
#' @param at          How many calls were procesed  up to this point
#' @param fail_on_error  Stop if error(s) occurred
#' @keywords internal
summarize_result = function(result, n_errors, n_warnings,
                            cond_msgs, at=length(result), fail_on_error=TRUE) {

    if (length(cond_msgs) > 50) {
        call_idx = as.integer(sub("\\((Error )?#([0-9]+)\\) .*", "\\2", cond_msgs))
        cond_msgs = utils::head(cond_msgs[order(call_idx)], 50)
    }
    detail = paste(cond_msgs, collapse="\n")

    if (n_errors > 0) {
        msg = sprintf("%i/%i jobs failed (%i warnings)", n_errors, at, n_warnings)
        if (fail_on_error)
            stop(msg, ". Stopping.\n", detail, call.=FALSE)
        else
            warning(msg, "\n", detail, immediate.=TRUE, call.=FALSE)
    } else if (n_warnings > 0) {
        msg = sprintf("%i warnings occurred in processing\n", n_warnings)
        warning(msg, detail, immediate.=TRUE, call.=FALSE)
    }
    unname(result)
}
