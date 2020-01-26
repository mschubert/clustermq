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
    zmq = ZeroMQ$new()

    # get address of master (or SSH tunnel)
    message("master ctl listening at: ", master_ctl)
    zmq$connect(master_job, socket_type="ZMQ_XREQ", sid="fwd_out")

    # set up local network forward to master (or SSH tunnel)
    net_port = zmq$listen(socket_type="ZMQ_XREP", sid="fwd_in")
    net_fwd = sprintf("tcp://%s:%i", host(), net_port)
    message("forwarding local network from: ", net_fwd)

    # connect to master
    zmq$connect(master_ctl, sid="ctl")
    zmq$send(data=list(id="PROXY_UP", worker_url=net_fwd), sid="ctl")
    message("sent PROXY_UP to master ctl")

    # receive common data
    msg = zmq$receive(sid="ctl")
    message("received common data:",
            utils::head(msg$fun), names(msg$const), names(msg$export), msg$seed)

    tryCatch({
        # set up qsys on cluster
        message("setting up qsys: ", qsys_id)
        if (toupper(qsys_id) %in% c("LOCAL", "SSH"))
            stop("Remote SSH QSys ", sQuote(qsys_id), " is not allowed")

        data_port = zmq$listen() # common data 'default' socket
        data_url = sprintf("tcp://%s:%i", host(), data_port)
        qsys = get(toupper(qsys_id), envir=parent.env(environment()))
        qsys = qsys$new(data=msg, zmq=zmq, master=net_fwd)
        redirect = list(id="PROXY_READY", data_url=data_url, token=qsys$data_token)
        zmq$send(data=redirect, sid="ctl")
        message("sent PROXY_READY to master ctl")

        while(TRUE) {
            events = zmq$poll(c("fwd_in", "ctl", "default"))

            # forwarding messages between workers and master
            if (events[1])
                zmq$send(zmq$receive("fwd_in", unserialize=FALSE), "fwd_out")

            # socket connecting proxy to master
            if (events[2]) {
                msg = zmq$receive("ctl")
                message("received: ", msg)
                switch(msg$id,
                    "PROXY_CMD" = {
                        reply = try(eval(msg$exec))
                        zmq$send(list(id="PROXY_CMD", reply=reply), "ctl")
                    },
                    "PROXY_STOP" = {
                        if (msg$finalize)
                            qsys$finalize()
                        break
                    }
                )
            }

            # socket connecting ssh_proxy to workers
            if (events[3]) {
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
        zmq$send(data, "ctl")
    })
}
