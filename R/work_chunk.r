#' Function to process a chunk of calls
#'
#' Each chunk comes encapsulated in a data.frame
#'
#' @param df           A data.frame with call IDs as rownames and arguments as columns
#' @param fun          The function to call
#' @param const_args   Constant arguments passed to each call
#' @param common_seed  A seed offset common to all function calls
#' @return             A list of call results (or try-error if they failed)
work_chunk = function(df, fun, const_args=list(), common_seed=NULL) {
    context = new.env()

    fwrap = function(..., ` id `, ` seed `=NA) {
        if (!is.na(` seed `))
            set.seed(` seed `)

        withCallingHandlers(
            withRestarts(
                do.call(fun, c(list(...), const_args)),
                muffleStop = function(e) structure(e, class="error")
            ),
            warning = function(w) {
                wmsg = paste0("(#", ` id `, ") ", conditionMessage(w))
                context$warnings = c(context$warnings, list(wmsg))
                invokeRestart("muffleWarning")
            },
            error = function(e) {
                err = paste0("(Error #", ` id `, ") ", conditionMessage(e))
                invokeRestart("muffleStop", err)
            }
        )
    }

    if (is.null(df$` id `))
        df$` id ` = seq_along(df[[1]])

    if (!is.null(common_seed))
        df$` seed ` = as.integer(df$` id ` %% .Machine$integer.max) - common_seed

    list(result = stats::setNames(purrr::pmap(df, fwrap), df$` id `),
         warnings = context$warnings)
}
