#' Setup routines for queueing systems
#'
#' If there are any option(...)s handle them here
#'
#' @return  A modified class
setup = list(
    lsf = function() {
        user_template = getOption("clustermq.template.lsf")
        if (length(user_template) == 0) {
            packageStartupMessage("* Option 'clustermq.template.lsf' not set, ",
                    "defaulting to package template")
            packageStartupMessage("--- see: https://github.com/mschubert/clustermq/wiki/LSF")
        } else {
            LSF$template = readChar(user_template, file.info(user_template)$size)
        }
        LSF
    },

    ssh = function() {
        host = getOption("clustermq.ssh.host")
        if (length(host) == 0) {
            packageStartupMessage("* Option 'clustermq.ssh.host' not set, ",
                    "trying to use it will fail")
            packageStartupMessage("--- see: https://github.com/mschubert/clustermq/wiki/SSH")
        } else {
            SSH$host = host
        }
        SSH
    }
)

#' Select the queueing system on package startup with user options
.onLoad = function(...) {
    qsys_id = tolower(getOption('clustermq.scheduler'))
    if (length(qsys_id) == 0) {
        packageStartupMessage("* Option 'clustermq.scheduler' not set, ",
                "defaulting to 'lsf'")
        qsys_id = "lsf"
        packageStartupMessage("--- see: https://github.com/mschubert/clustermq/wiki#setting-up-the-scheduler")
    }

    assign("qsys_id", qsys_id, envir=parent.env(environment()))
    assign("qsys", setup[[qsys_id]](), envir=parent.env(environment()))
}
