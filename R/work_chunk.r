#' Function to process a chunk of calls
#'
#' Each chunk comes encapsulated in a data.frame
#'
#' @param df           A data.frame with call IDs as rownames and arguments as columns
#' @param fun          The function to call
#' @param const        Constant arguments passed to each call
#' @param rettype      Return type of function
#' @param common_seed  A seed offset common to all function calls
#' @param progress     Logical indicated whether to display a progress bar
#' @return             A list of call results (or try-error if they failed)
#' @keywords internal
work_chunk = function(df, fun, const=list(), rettype="list",
                      common_seed=NULL, progress=FALSE) {
    context = new.env()
    context$warnings = list()
    context$errors = list()
    if (progress) {
        pb = progress::progress_bar$new(total = nrow(df),
                                        format = "[:bar] :percent eta: :eta")
        pb$tick(0)
    }

    fwrap = function(..., ` id `, ` seed `=NA) {
        chr_id = as.character(` id `)
        if (!is.na(` seed `))
            set.seed(` seed `)

        result = withCallingHandlers(
            withRestarts(
                do.call(fun, c(list(...), const)),
                muffleStop = function(e) if (rettype == "list")
                    structure(e, class="error")
            ),
            warning = function(w) {
                wmsg = paste0("(#", chr_id, ") ", conditionMessage(w))
                context$warnings[[chr_id]] = wmsg
                invokeRestart("muffleWarning")
            },
            error = function(e) {
                emsg = paste0("(Error #", chr_id, ") ", conditionMessage(e))
                context$errors[[chr_id]] = emsg
                invokeRestart("muffleStop", emsg)
            }
        )

        if (progress)
            pb$tick()
        result
    }

    if (is.null(df$` id `))
        df$` id ` = seq_along(df[[1]])

    if (!is.null(common_seed))
        df$` seed ` = as.integer(df$` id ` %% .Machine$integer.max) - common_seed

    re = stats::setNames(purrr_lookup[[rettype]](df, fwrap), df$` id `)
    if (rettype != "list")
        re = unlist(re)
    list(result = re, warnings = context$warnings, errors = context$errors)
}
