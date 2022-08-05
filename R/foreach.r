#' Register clustermq as `foreach` parallel handler
#'
#' @param ...  List of arguments passed to the `Q` function, e.g. n_jobs
#' @export
register_dopar_cmq = function(...) {
    dots = list(...)
    workers = NA
    if ("n_jobs" %in% names(dots))
        workers = dots$n_jobs
    info = function(data, item) {
        switch(item,
               name = "clustermq",
               version = utils::packageVersion("clustermq"),
               workers = workers)
    }
    foreach::setDoPar(cmq_foreach, data=dots, info=info)
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
#' @keywords  internal
cmq_foreach = function(obj, expr, envir, data) {
    stopifnot(inherits(obj, "foreach"))
    stopifnot(inherits(envir, "environment"))

    it = iterators::iter(obj)
    args_df = do.call(rbind, as.list(it))

    # if we call a function by name, add it to the export list
    if (is.call(expr) && as.character(expr[[1]]) != "{")
        obj$export = c(as.character(expr[[1]]), obj$export)

    # wrap whatever we call in a function for use with Q(...)
    fun = function(...) NULL
    formals(fun) = c(stats::setNames(replicate(ncol(args_df), substitute()),
                                     obj$argnames),
                     formals(fun))
    body(fun) = expr

    # scan 'expr' for exports, eval and add objects ref'd in '.export'
    export_env = new.env(parent=envir)
    foreach::getexports(expr, e=export_env, env=envir)
    obj$export = unique(c(obj$export, ls(export_env)))
    if (length(obj$export) > 0) {
        export = as.list(mget(obj$export, envir=export_env, inherits=TRUE))
        data$export = utils::modifyList(as.list(data$export), export, keep.null=TRUE)
        for (i in seq_along(data$export))
            if (inherits(data$export[[i]], "function")) # strip attached objs
                environment(data$export[[i]]) = .GlobalEnv
    }

    # make sure packages are loaded on the dopar target
    if (length(obj$packages) > 0) {
        data$pkgs = unique(c(data$pkgs, obj$packages))
    }

    result = do.call(Q_rows, c(list(df=args_df, fun=fun), data))

    accum = foreach::makeAccum(it)
    accum(result, tags=seq_along(result))
    foreach::getResult(it)
}
