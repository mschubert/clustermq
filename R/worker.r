#' R worker submitted as cluster job
#'
#' Do not call this manually, the master will do that
#'
#' @param master   The master address (tcp://ip:port)
#' @param timeout  Time until worker shuts down without hearing from master
#' @param ...      Catch-all to not break older template values (ignored)
#' @param verbose  Whether to print debug messages
#' @keywords internal
worker = function(master, timeout=600, ..., verbose=TRUE) {
    if (verbose)
        message = function(...) base::message(format(Sys.time(), "%Y-%m-%d %H:%M:%OS9 | "), ...)
    else
        message = function(...) invisible(NULL)

    #TODO: replace this by proper authentication
    auth = Sys.getenv("CMQ_AUTH")

    message("Master: ", master)
    if (length(list(...)) > 0)
        warning("Arguments ignored: ", paste(names(list(...)), collapse=", "))

    # connect to master
    zmq_context = init_context()
    socket = init_socket(zmq_context, "ZMQ_REQ")
#    set.send.timeout(socket, as.integer(timeout * 1000)) # msec

    # send the master a ready signal
    connect_socket(socket, master)
    send_socket(socket, data=list(id="WORKER_UP", auth=auth,
                pkgver=utils::packageVersion("clustermq")))
	message("WORKER_UP to: ", master)

    fmt = "%i in %.2fs [user], %.2fs [system], %.2fs [elapsed]"
    start_time = proc.time()
    counter = 0
    common_data = NA
    token = NA

    while(TRUE) {
        events = poll_socket(list(socket), timeout=timeout * 1000)
        if (events[1]) {
            tic = proc.time()
            msg = receive_socket(socket)
            delta = proc.time() - tic
            message(sprintf("> %s (%.3fs wait)", msg$id, delta[3]))
        } else
            stop("Timeout reached, terminating")

        switch(msg$id,
            "DO_CALL" = {
                result = try(eval(msg$expr, envir=msg$env))
                message("eval'd: ", msg$expr)
                counter = counter + 1
                send_socket(socket, data=list(id="WORKER_READY", auth=auth,
                    token=token, n_calls=counter, ref=msg$ref, result=result))
            },
            "DO_SETUP" = {
                if (!is.null(msg$redirect)) {
                    data_socket = init_socket(zmq_context, "ZMQ_REQ")
                    connect_socket(data_socket, msg$redirect)
                    send_socket(data_socket, data=list(id="WORKER_READY", auth=auth))
                    message("WORKER_READY to redirect: ", msg$redirect)
                    msg = receive_socket(data_socket)
                }
                need = c("id", "fun", "const", "export", "pkgs",
                         "rettype", "common_seed", "token")
                if (setequal(names(msg), need)) {
                    common_data = msg[setdiff(need, c("id", "export", "pkgs", "token"))]
                    list2env(msg$export, envir=.GlobalEnv)
                    token = msg$token
                    message("token from msg: ", token)
                    for (pkg in msg$pkgs)
                        library(pkg, character.only=TRUE) #TODO: in its own namespace
                    send_socket(socket, data=list(id="WORKER_READY",
                                auth=auth, token=token, n_calls=counter))
                } else {
                    msg = paste("wrong field names for DO_SETUP:",
                                setdiff(names(msg), need))
                    send_socket(socket, data=list(id="WORKER_ERROR", auth=auth, msg=msg))
                }
            },
            "DO_CHUNK" = {
                if (!identical(token, msg$token)) {
                    msg = paste("mismatch chunk & common data", token, msg$token)
                    send_socket(socket, send_more=TRUE,
                        data=list(id="WORKER_ERROR", auth=auth, msg=msg))
                    message("WORKER_ERROR: ", msg)
                    break
                }

                tic = proc.time()
                result = tryCatch(
                    do.call(work_chunk, c(list(df=msg$chunk), common_data)),
                    error = function(e) e)
                delta = proc.time() - tic

                if ("error" %in% class(result)) {
                    send_socket(socket, send_more=TRUE,
                        data=list(id="WORKER_ERROR", auth=auth, msg=conditionMessage(result)))
                    message("WORKER_ERROR: ", conditionMessage(result))
                    break
                } else {
                    message("completed ", sprintf(fmt, length(result$result),
                        delta[1], delta[2], delta[3]))
                    counter = counter + length(result$result)
                    send_data = c(list(id="WORKER_READY", auth=auth, token=token,
                                       n_calls=counter), result)
                    send_socket(socket, send_data)
                }
            },
            "WORKER_WAIT" = {
                message(sprintf("waiting %.2fs", msg$wait))
                Sys.sleep(msg$wait)
                send_socket(socket, data=list(id="WORKER_READY", auth=auth, token=token))
            },
            "WORKER_STOP" = {
                break
            }
        )
    }

    run_time = proc.time() - start_time

    message("shutting down worker")
    send_socket(socket, data = list(
        id = "WORKER_DONE",
        time = run_time,
        mem = sum(gc()[,6]),
        calls = counter,
        auth = auth
    ))

    message("\nTotal: ", sprintf(fmt, counter, run_time[1], run_time[2], run_time[3]))
}
