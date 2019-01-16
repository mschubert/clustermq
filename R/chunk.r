#' Subset index chunk for processing
#'
#' 'attr' in `[.data.frame` takes too much CPU time
#'
#' @param x  Index data.frame
#' @param i  Rows to subset
#' @return   x[i,]
#' @keywords  internal
chunk = function(x, i) {
    re = lapply(x, `[`, i=i)
    re$` id ` = i
    re
}
