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
    process_id = function(id) {
        if (!is.null(common_seed))
            set.seed(common_seed + as.integer(id))

        iter = stats::setNames(unlist(df[id,], recursive=FALSE), colnames(df))
        result = try(do.call(fun, c(iter, const_args)))
    }
    lapply(rownames(df), process_id)
}
