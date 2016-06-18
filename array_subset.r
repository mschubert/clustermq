#' Subsets an array using a list with indices or names
#'
#' @param X      The array to subset
#' @param index  A list of vectors to use for subsetting, or vector if along is given
#' @param along  Along which dimension to subset if index is a vector; default is last dimension
#' @return       The subset of the array
subset = function(X, index, along=NULL, drop=FALSE) {
    if (!is.list(index)) {
        # this is required because as.array() will fail on dplyr:df
        if (is.data.frame(X))
            ndim_X = length(dim(X))
        else
            ndim_X = length(dim(as.array(X)))

        # create a subsetting list that covers the whole array first,
        # then set the dimension we are working on to what is requested
        tmp = rep(list(TRUE), ndim_X)

        # by default, subset the last dimension
        if (is.null(along))
            along = ndim_X
        tmp[[along]] = index
        index = tmp
    }

    do.call(function(...) `[`(X, ..., drop=drop), index)
}
