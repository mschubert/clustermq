#' SSH proxy for different schedulers
#'
#' Do not call this manually, the SSH qsys will do that
#'
#' @param ctl      The port to connect to the master for proxy control
#' @param job      The port to connect to the master for job control
#' @param qsys_id  Character string of QSys class to use
#' @keywords internal
ssh_proxy = function(ctl, job, qsys_id=qsys_default) {
    master_ctl = sprintf("tcp://127.0.0.1:%i", ctl)
    master_job = sprintf("tcp://127.0.0.1:%i", job)
    zmq = ZeroMQ$new()

    # get address of master (or SSH tunnel)
    message("master ctl listening at: ", master_ctl)
    zmq$connect(master_job, socket_type="ZMQ_REQ", sid="fwd_out") # XREQ cur not working

    # set up local network forward to master (or SSH tunnel)
    net_fwd = zmq$listen(socket_type="ZMQ_REP", sid="fwd_in") # XREP cur not working
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

        data_url = zmq$listen(sid="default") # common data 'default' socket
        qsys = get(toupper(qsys_id), envir=parent.env(environment()))
        qsys = qsys$new(data=msg, zmq=zmq, addr=net_fwd, bind=FALSE)
        on.exit(qsys$cleanup())

        redirect = list(id="PROXY_READY", data_url=data_url, token=qsys$data_token)
        zmq$send(data=redirect, sid="ctl")
        message("sent PROXY_READY to master ctl")

        while(TRUE) {
            events = zmq$poll(c("fwd_in", "fwd_out", "ctl", "default"))

            # forwarding messages between workers and master
            if (events[1])
                zmq$send(zmq$receive("fwd_in", unserialize=FALSE), "fwd_out")
            if (events[2])
                zmq$send(zmq$receive("fwd_out", unserialize=FALSE), "fwd_in")

            # socket connecting proxy to master
            if (events[3]) {
                msg = zmq$receive("ctl")
                message("received: ", msg)
                switch(msg$id,
                    "PROXY_CMD" = {
                        reply = try(eval(msg$exec))
                        zmq$send(list(id="PROXY_CMD", reply=reply), "ctl")
                    },
                    "PROXY_STOP" = {
                        zmq$send(list(id="PROXY_STOP"), "ctl")
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
        message(data)
        zmq$send(data, "ctl")
    })
}
