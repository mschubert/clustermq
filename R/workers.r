#' Creates a pool of workers
#'
#' @param n_jobs      Number of jobs to submit
#' @param data        Set common data (function, constant args, seed)
#' @param reuse       Whether workers are reusable or get shut down after call
#' @param template    A named list of values to fill in template
#' @param log_worker  Write a log file for each worker
#' @param qsys_id     Character string of QSys class to use
#' @return            An instance of the QSys class
#' @export
workers = function(n_jobs, data=NULL, reuse=TRUE, template=list(),
                   log_worker=FALSE, qsys_id=qsys_default) {
    qsys = get(toupper(qsys_id), envir=parent.env(environment()))
    if ("setup" %in% ls(qsys))
        qsys = qsys$setup()

    qsys = qsys$new(data=data, reuse=reuse)
    on.exit(qsys$cleanup)

    message("Submitting ", n_jobs, " worker jobs (ID: ", qsys$id, ") ...")
    qsys$submit_jobs(n_jobs, template=template, log_worker=log_worker)

    on.exit()
    qsys
}
