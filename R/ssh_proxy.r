#' SSH proxy for different schedulers
#'
#' Do not call this manually, the SSH qsys will do that
#'
#' @param ctl      The port to connect to the master for proxy control
#' @param job      The port to connect to the master for job control
#' @param qsys_id  Character string of QSys class to use
#' @keywords internal
ssh_proxy = function(ctl, job, qsys_id=qsys_default) {
    master_ctl = sprintf("tcp://localhost:%i", ctl)
    master_job = sprintf("tcp://localhost:%i", job)
    context = init_context()

    # get address of master (or SSH tunnel)
    message("master ctl listening at: ", master_ctl)
    fwd_out = init_socket(context, "ZMQ_XREQ")
    connect_socket(fwd_out, master_job)

    # set up local network forward to master (or SSH tunnel)
    fwd_in = init_socket(context, "ZMQ_XREP")
    net_port = bind_avail(fwd_in, 8000:9999)
    net_fwd = sprintf("tcp://%s:%i", host(), net_port)
    message("forwarding local network from: ", net_fwd)

    # connect to master
    ctl_socket = init_socket(context, "ZMQ_REQ")
    connect_socket(ctl_socket, master_ctl)
    send_socket(ctl_socket, data=list(id="PROXY_UP"))
    message("sent PROXY_UP to master ctl")

    # receive common data
    msg = receive_socket(ctl_socket)
    message("received common data:",
            utils::head(msg$fun), names(msg$const), names(msg$export), msg$seed)

    tryCatch({
        # set up qsys on cluster
        message("setting up qsys: ", qsys_id)
        if (toupper(qsys_id) %in% c("LOCAL", "SSH"))
            stop("Remote SSH QSys ", sQuote(qsys_id), " is not allowed")

        qsys = get(toupper(qsys_id), envir=parent.env(environment()))
        qsys = qsys$new(data=msg, master=net_fwd)
        redirect = list(id="PROXY_READY", data_url=qsys$url, token=qsys$data_token)
        send_socket(ctl_socket, data=redirect)
        message("sent PROXY_READY to master ctl")

        while(TRUE) {
            events = poll_socket(list(fwd_in, fwd_out, ctl_socket, qsys$sock))

            # forwarding messages between workers and master
            if (events[1])
                send_socket(fwd_out, receive_socket(fwd_in, unserialize=FALSE))
            if (events[2])
                send_socket(fwd_in, receive_socket(fwd_out, unserialize=FALSE))

            # socket connecting proxy to master
            if (events[3]) {
                msg = receive_socket(ctl_socket)
                message("received: ", msg)
                switch(msg$id,
                    "PROXY_CMD" = {
                        reply = try(eval(msg$exec))
                        send_socket(ctl_socket,
                                    data = list(id="PROXY_CMD", reply=reply))
                    },
                    "PROXY_STOP" = {
                        if (msg$finalize)
                            qsys$finalize()
                        break
                    }
                )
            }

            # socket connecting ssh_proxy to workers
            if (events[4]) {
                msg = qsys$receive_data(with_checks=FALSE)
                message("received: ", msg)
                switch(msg$id,
                    "WORKER_READY" = {
                        qsys$send_common_data()
                    }
                )
            }
        }

        message("shutting down and cleaning up")

    }, error = function(e) {
        data = list(id=paste("PROXY_ERROR:", conditionMessage(e)))
        send_socket(ctl_socket, data=data)
    })
}
