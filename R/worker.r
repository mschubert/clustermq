loadModule("cmq_worker", TRUE) # CMQWorker C++ class
utils::globalVariables(c("common_seed", "const", "fun")) # worker .GlobalEnv

#' R worker submitted as cluster job
#'
#' Do not call this manually, the master will do that
#'
#' @param master   The master address (tcp://ip:port)
#' @param ...      Catch-all to not break older template values (ignored)
#' @param verbose  Whether to print debug messages
#' @param context  ZeroMQ context (for internal testing)
#' @keywords internal
worker = function(master, ..., verbose=TRUE, context=NULL) {
    message = msg_fmt(verbose)

    #TODO: replace this by proper authentication
    auth = Sys.getenv("CMQ_AUTH")

    message("Master: ", master)
    if (length(list(...)) > 0)
        warning("Arguments ignored: ", paste(names(list(...)), collapse=", "))

    # connect to master
    if (is.null(context))
        w = methods::new(CMQWorker)
    else
        w = methods::new(CMQWorker, context)
    message("connecting to: ", master)
    w$connect(master, 10000L)

    counter = 0
    repeat {
        tic = proc.time()
        w$poll()
        delta = proc.time() - tic
        counter = counter + 1
        message(sprintf("> call %i (%.3fs wait)", counter, delta[3]))
        if (! w$process_one())
            break
    }

    message("shutting down worker")
    run_time = proc.time()
    fmt = "%i in %.2fs [user], %.2fs [system], %.2fs [elapsed]"
    message("\nTotal: ", sprintf(fmt, counter, run_time[1], run_time[2], run_time[3]))
}
