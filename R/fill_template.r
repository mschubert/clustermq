#' Fill a QSys template will values supplied
#'
#' @param template    Job submission template
#' @param master      The address of the master; this is required
#' @param values      Values as named list
#' @param ...         Additional values as key-value pairs (take precendence)
#' @param log_worker  Whether to log worker (default: FALSE)
#' @return            A filled template
fill_template = function(template, master, values=list(), ..., log_worker=FALSE) {
    values = utils::modifyList(values, list(...))
    values$job_name = paste0("cmq", rev(strsplit(master, "[:/]")[[1]])[1])
    values$master = master
    if (log_worker)
        values$log_file = paste0(values$job_name, ".log")

    infuser::infuse(template, values, strict=TRUE)
}
