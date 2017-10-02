#' R worker submitted as cluster job
#'
#' Do not call this manually, the master will do that
#'
#' @param master     The master address (tcp://ip:port)
worker = function(master) {
    print(master)

    # connect to master
#    assign("zmq_context", rzmq::init.context(), envir=.GlobalEnv)
    zmq_context = rzmq::init.context()
    socket = rzmq::init.socket(zmq_context, "ZMQ_REQ")
    #rzmq::set.send.timeout(socket, 10000L) # milliseconds

    # send the master a ready signal
    rzmq::connect.socket(socket, master)
    rzmq::send.socket(socket, data=list(id="WORKER_UP"))
	message("WORKER_UP to: ", master)

    start_time = proc.time()
    counter = 0
    common_data = NA
    token = NA

    while(TRUE) {
        #TODO: set timeout to something more reasonable
        #  when data sending is separated from main loop
        tt = proc.time()
        events = rzmq::poll.socket(list(socket), list("read"), timeout=3600)
        if (events[[1]]$read) {
            msg = rzmq::receive.socket(socket)
            message(sprintf("received after %.3fs: %s",
                            (proc.time()-tt)[[3]], msg$id))
        } else
            stop("Timeout reached, terminating")

        switch(msg$id,
            "DO_SETUP" = {
                if (!is.null(msg$redirect)) {
                    data_socket = rzmq::init.socket(zmq_context, "ZMQ_REQ")
                    rzmq::connect.socket(data_socket, msg$redirect)
                    rzmq::send.socket(data_socket, data=list(id="WORKER_UP"))
                    message("WORKER_UP to redirect: ", msg$redirect)
                    msg = rzmq::receive.socket(data_socket)
                }
                need = c("id", "fun", "const", "export", "common_seed", "token")
                if (setequal(names(msg), need)) {
                    common_data = msg[c('fun', 'const', 'common_seed')]
                    list2env(msg$export, envir=.GlobalEnv)
                    token = msg$token
                    message("token from msg: ", token)
                    rzmq::send.socket(socket, data=list(id="WORKER_READY",
                                      token=token))
                } else {
                    msg = paste("wrong field names for DO_SETUP:",
                                setdiff(names(msg), need))
                    rzmq::send.socket(socket, data=list(id="WORKER_ERROR", msg=msg))
                }
            },
            "DO_CHUNK" = {
                if (identical(token, msg$token)) {
                    result = do.call(work_chunk, c(list(df=msg$chunk), common_data))
                    message(sprintf("completed %i in %s: ",
                                    length(result$result),
                                    paste(proc.time() - tt, collapse=":")),
                                    paste(rownames(msg$chunk), collapse=", "))
                    send_data = c(list(id="WORKER_READY", token=token), result)
                    rzmq::send.socket(socket, send_data)
                    counter = counter + length(result)
                    print(pryr::mem_used())
                } else {
                    msg = paste("mismatch chunk & common data", token, msg$token)
                    rzmq::send.socket(socket, data=list(id="WORKER_ERROR", msg=msg))
                }
            },
            "WORKER_WAIT" = {
                message(sprintf("waiting %.2fs", msg$wait))
                Sys.sleep(msg$wait)
                rzmq::send.socket(socket, data=list(id="WORKER_READY", token=token))
            },
            "WORKER_STOP" = {
                break
            }
        )
    }

    run_time = proc.time() - start_time

    message("shutting down worker")
    rzmq::send.socket(socket, data = list(
        id = "WORKER_DONE",
        time = run_time,
        calls = counter
    ))

    print(run_time)
}
