loadModule("cmq_proxy", TRUE) # CMQProxy C++ class

#' SSH proxy for different schedulers
#'
#' Do not call this manually, the SSH qsys will do that
#'
#' @param fwd_port The port of the master address to connect to
#'                 (remote end of reverse tunnel)
#' @param qsys_id  Character string of QSys class to use
#' @keywords internal
ssh_proxy = function(fwd_port, qsys_id=qsys_default) {
    message = msg_fmt()

    master = sprintf("tcp://127.0.0.1:%s", fwd_port)
    p = methods::new(CMQProxy)
    p$connect(master, 10000L)

    tryCatch({
        nodename = Sys.info()["nodename"]
        addr = p$listen(sub(nodename, "*", sample(host()), fixed=TRUE))
        addr = sub("0.0.0.0", nodename, addr, fixed=TRUE)
        message("listening for workers at ", addr)

        p$proxy_request_cmd()
        args = p$proxy_receive_cmd()
        message("submit args: ", paste(mapply(paste, names(args), args, sep="="), collapse=", "))
        stopifnot(inherits(args, "list"), "n_jobs" %in% names(args))

        # set up qsys on cluster
        message("setting up qsys: ", qsys_id)
        if (toupper(qsys_id) %in% c("LOCAL", "SSH"))
            stop("Remote SSH QSys ", sQuote(qsys_id), " is not allowed")
        qsys = get(toupper(qsys_id), envir=parent.env(environment()))
        qsys = do.call(qsys$new, c(list(addr=addr, master=p), args))
        on.exit(qsys$cleanup())

        while(p$process_one()) {
            message("event at: ", Sys.time())
        }

        message("shutting down")
        p$close(1000L)

    }, error = function(e) {
        stop(e)
    })
}
