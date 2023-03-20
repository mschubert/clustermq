loadModule("cmq_proxy", TRUE) # CMQProxy C++ class

#' SSH proxy for different schedulers
#'
#' Do not call this manually, the SSH qsys will do that
#'
#' @param master   The master address to connect to (remote end of reverse tunnel)
#' @param qsys_id  Character string of QSys class to use
#' @keywords internal
ssh_proxy = function(master, qsys_id=qsys_default) {
    p = methods::new(CMQProxy)
    p$connect(master, 10000L)

    tryCatch({
        addr = p$listen()
        p$proxy_request_cmd()

        # set up qsys on cluster
        message("setting up qsys: ", qsys_id)
        if (toupper(qsys_id) %in% c("LOCAL", "SSH"))
            stop("Remote SSH QSys ", sQuote(qsys_id), " is not allowed")
        qsys = get(toupper(qsys_id), envir=parent.env(environment()))
        qsys = qsys$new(addr)
        on.exit(qsys$cleanup())

        args = p$proxy_receive_cmd()
        message("submit args: ", paste(mapply(paste, names(args), args, sep="="), collapse=", "))
        do.call(qsys$submit_jobs, args)

        while(p$process_one()) {}

        p$close()

    }, error = function(e) {
        stop(e)
    })
}
