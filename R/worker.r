#' R worker submitted as cluster job
#'
#' Do not call this manually, the master will do that
#'
#' @param worker_id  The ID of the worker (usually just numbered)
#' @param master     The master address (tcp://ip:port)
#' @param memlimit   Maximum memory before throwing an error
worker = function(worker_id, master, memlimit) {
    print(master)
    print(memlimit)

    # connect to master
    context = rzmq::init.context()
    socket = rzmq::init.socket(context, "ZMQ_REQ")
    #rzmq::set.send.timeout(socket, 10000L) # milliseconds

    # send the master a ready signal
    rzmq::connect.socket(socket, master)
    rzmq::send.socket(socket, data=list(id="WORKER_UP", worker_id=worker_id))
	message("WORKER_UP to: ", master)

    start_time = proc.time()
    counter = 0
    common_data = NA
    token = NA

    while(TRUE) {
        #TODO: set timeout to something more reasonable
        #  when data sending is separated from main loop
        events = rzmq::poll.socket(list(socket), list("read"), timeout=3600)
        if (events[[1]]$read) {
            msg = rzmq::receive.socket(socket)
            message("received: ", msg$id)
        } else
            stop("Timeout reached, terminating")

        switch(msg$id,
            "DO_SETUP" = {
                if (!is.null(msg$redirect)) {
                    data_socket = rzmq::init.socket(context, "ZMQ_REQ")
                    rzmq::connect.socket(data_socket, msg$redirect)
                    rzmq::send.socket(data_socket, data=list(id="WORKER_UP"))
                    message("WORKER_UP to redirect: ", msg$redirect)
                    msg = rzmq::receive.socket(data_socket)
                }
                common_data = msg[c('fun', 'const', 'common_seed')]
                list2env(msg$export, envir=.GlobalEnv)
                token = msg$token
                message("token from msg: ", token)
                rzmq::send.socket(socket, data=list(id="WORKER_READY"))
            },
            "DO_CHUNK" = {
                if (identical(token, msg$token)) {
                    result = do.call(work_chunk, c(list(df=msg$chunk), common_data))
                    message("completed: ", paste(rownames(msg$chunk), collapse=", "))
                    rzmq::send.socket(socket, data=c(list(id="WORKER_READY"), result))
                    counter = counter + length(result)
                    print(pryr::mem_used())
                } else
                    rzmq::send.socket(socket, data=list(id="WORKER_ERROR",
                                msg=paste("chunk does not match common data", token, msg$token)))
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
        worker_id = worker_id,
        time = run_time,
        calls = counter
    ))

    print(run_time)
}
