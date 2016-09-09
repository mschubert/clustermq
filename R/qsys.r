#' Setup routines for queueing systems
#'
#' If there are any option(...)s handle them here
#'
#' @param qsys  A QSys-derived class
#' @return      A modified class
setup = list(
    lsf = function() {
        user_template = getOption("clustermq.template.lsf")
        if (length(user_template) == 0) {
            packageStartupMessage("* Option 'clustermq.template.lsf' not set, ",
                    "defaulting to package template")
        } else {
            LSF$template = readChar(user_template, file.info(user_template)$size)
        }
        LSF
    }
)

#' Select the queueing system on package startup with user options
.onLoad = function(...) {
    qsys_id = tolower(getOption('clustermq.scheduler'))
    if (length(qsys_id) == 0) {
        packageStartupMessage("* Option 'clustermq.scheduler' not set, ",
                "defaulting to 'lsf'")
        qsys_id = "lsf"
    }

    assign("qsys", setup[[qsys_id]](), envir=parent.env(environment()))
}
