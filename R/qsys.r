.onLoad = function(...) {
    qsys_id = tolower(getOption('clustermq.scheduler'))
    if (length(qsys_id) == 0) {
        packageStartupMessage("* Option 'clustermq.scheduler' not set, ",
                "defaulting to 'lsf'")
        qsys_id = "lsf"
    }
    qsys = get(qsys_id)

    user_template = getOption("clustermq.template.lsf")
    if (length(user_template) == 0) {
        packageStartupMessage("* Option 'clustermq.template.lsf' not set, ",
                "defaulting to package template")
    } else {
        qsys$template = readChar(user_template, file.info(user_template)$size)
    }

    assign("qsys", qsys, envir=parent.env(environment()))
}
