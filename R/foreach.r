#' Register clustermq as `foreach` parallel handler
#'
#' @param ...  List of arguments passed to the `Q` function, e.g. n_jobs
#' @export
register_dopar_cmq = function(...) {
    info = function(data, item)
        switch(item, name="clustermq", version=utils::packageVersion("clustermq"))
    foreach::setDoPar(cmq_foreach, data=list(...), info=info)
}

#' clustermq foreach handler
#'
#' @param obj  Returned from foreach::foreach, containing the following variables:
#'   args    : Arguments passed, each as a call
#'   argnames: character vector of arguments passed
#'   evalenv : Environment where to evaluate the arguments
#'   export  : character vector of variable names to export to nodes
#'   packages: character vector of required packages
#'   verbose : whether to print status messages [logical]
#'   errorHandling: string of function name to call error with, e.g. "stop"
#' @param expr   An R expression in curly braces
#' @param envir  Environment where to evaluate the arguments
#' @param data   Common arguments passed by register_dopcar_cmq(), e.g. n_jobs
cmq_foreach = function(obj, expr, envir, data) {
    stopifnot(inherits(obj, "foreach"))
    stopifnot(inherits(envir, "environment"))

    it = iterators::iter(obj)
    args_df = do.call(rbind, as.list(it))

    fun = function() NULL
    formals(fun) = stats::setNames(replicate(ncol(args_df), substitute()), obj$argnames)
    body(fun) = expr

    data$export = utils::modifyList(as.list(data$export), as.list(obj$export))
#    data$packages = utils::modifyList(as.list(data$packages), as.list(obj$packages))

    do.call(Q_rows, c(list(df=args_df, fun=fun), data))
}
