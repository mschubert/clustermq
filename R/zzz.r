#' Select the queueing system on package loading
#'
#' This is done by setting the variable 'qsys' in the package environment
#' to the object that contains the desired queueing system. We further call
#' its setup() function if it exists, and set the variable 'qsys_id' to
#' the scheduler we use
.onLoad = function(libname, pkgname) {
    qsys_default = toupper(getOption('clustermq.scheduler'))

    if (length(qsys_default) == 0) {
        qname = c("SLURM", "LSF", "SGE", "LOCAL")
        exec = Sys.which(c("sbatch", "bsub", "qsh"))
        select = c(which(nchar(exec) > 0), 4)[1]
        qsys_default = qname[select]
    }

    assign("qsys_default", qsys_default, envir=parent.env(environment()))
}

#' Report queueing system on package attach if not set
.onAttach = function(libname, pkgname) {
    if (is.null(getOption("clustermq.scheduler"))) {
        packageStartupMessage("* Option 'clustermq.scheduler' not set, ",
                "defaulting to ", sQuote(qsys_default))
        packageStartupMessage("--- see: https://github.com/mschubert/clustermq/wiki#setting-up-the-scheduler")
    }
}
