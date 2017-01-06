#' Queue function calls on the cluster
#'
#' @param iter            Objects to be iterated in each function call
#' @param expand_grid     Use all combinations of arguments in `...`
#' @param split_array_by  The dimension number to split any arrays in `...`; default: last
#' @return                A data.frame that holds all call arguments
Q_call_index = function(iter, expand_grid=FALSE, split_array_by=NA) {
    # convert matrices to lists so they can be vectorised over
    split_arrays = function(x) {
        if (is.array(x))
            narray::split(x, along=ifelse(is.na(split_array_by), -1, split_array_by))
        else
            x
    }
    iter_split = lapply(iter, split_arrays)

    if (expand_grid)
        iter_split = do.call(expand.grid, c(iter_split,
                list(KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)))

    # prepare data and other args
    as.data.frame(do.call(tibble::data_frame, iter_split))
}
