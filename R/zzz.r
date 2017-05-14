#' Select the queueing system on package loading
#'
#' This is done by setting the variable 'qsys' in the package environment
#' to the object that contains the desired queueing system. We further call
#' its setup() function if it exists, and set the variable 'qsys_id' to
#' the scheduler we use
.onLoad = function(libname, pkgname) {
    qsys_id = toupper(getOption('clustermq.scheduler', default="local"))
    assign("qsys_id", qsys_id, envir=parent.env(environment()))

    if (qsys_id == "LOCAL") {
        packageStartupMessage("* Option 'clustermq.scheduler' not set, ",
                "defaulting to ", sQuote(qsys_id))
        packageStartupMessage("--- see: https://github.com/mschubert/clustermq/wiki#setting-up-the-scheduler")
    } else {
        qsys = tryCatch(parent.env(environment())[[qsys_id]],
            error = function(e) stop("QSys not found: ", sQuote(qsys_id)))

        if ("setup" %in% ls(qsys))
            qsys = qsys$setup()

        assign("qsys", qsys, envir=parent.env(environment()))
    }
}
