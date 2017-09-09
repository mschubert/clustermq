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

    fwrap = function(..., ` id `=NULL, ` seed `=NA) {
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

    df$` id ` = rownames(df)
    if (!is.null(common_seed))
        df$` seed ` = common_seed + as.integer(rownames(df))

    list(result = stats::setNames(purrr::pmap(df, fwrap), rownames(df)),
         warnings = context$warnings)
}
