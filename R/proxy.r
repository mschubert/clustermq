#' SSH proxy for different schedulers
#'
#' Do not call this manually, the SSH qsys will do that
#'
#' @param ctl  The port to connect to the master for proxy control
#' @param job  The port to connect to the master for job control
proxy = function(ctl, job) {
    master_ctl = sprintf("tcp://localhost:%i", ctl)
    master_job = sprintf("tcp://localhost:%i", job)
    context = rzmq::init.context()

    # get address of master (or SSH tunnel)
    message("master ctl listening at: ", master_ctl)
    fwd_out = rzmq::init.socket(context, "ZMQ_XREQ")
    re = rzmq::connect.socket(fwd_out, master_job)
    if (!re)
        stop("failed to connect to master ctl")

    # set up local network forward to master (or SSH tunnel)
    fwd_in = rzmq::init.socket(context, "ZMQ_XREP")
    net_port = bind_avail(fwd_in, 8000:9999)
    net_fwd = sprintf("tcp://%s:%i", Sys.info()[['nodename']], net_port)
    message("forwarding local network from: ", net_fwd)

    # connect to master
    ctl_socket = rzmq::init.socket(context, "ZMQ_REQ")
    rzmq::connect.socket(ctl_socket, master_ctl)
    rzmq::send.socket(ctl_socket, data=list(id="PROXY_UP"))
    message("sent PROXY_UP to master ctl")

    # receive common data
    msg = rzmq::receive.socket(ctl_socket)
    message("received common data:",
            utils::head(msg$fun), names(msg$const), names(msg$export), msg$seed)
    qsys = qsys$new(data=msg, master=net_fwd)
    rzmq::send.socket(ctl_socket,
                      data = list(id="PROXY_READY", data_url=qsys$url)) # url$data w/ mod
    message("sent PROXY_READY to master ctl")

    while(TRUE) {
        events = rzmq::poll.socket(list(fwd_in, fwd_out, ctl_socket, qsys$sock),
                                   rep(list("read"), 4),
                                   timeout=-1L)

        # forwarding messages between workers and master
        if (events[[1]]$read)
            rzmq::send.multipart(fwd_out, rzmq::receive.multipart(fwd_in))
        if (events[[2]]$read)
            rzmq::send.multipart(fwd_in, rzmq::receive.multipart(fwd_out))

        # socket connecting proxy to master
        if (events[[3]]$read) {
            msg = rzmq::receive.socket(ctl_socket)
            message("received: ", msg)
            switch(msg$id,
                "PROXY_CMD" = {
                    reply = try(eval(msg$exec))
                    rzmq::send.socket(ctl_socket,
                                      data = list(id="PROXY_CMD", reply=reply))
                },
                "PROXY_STOP" = {
                    break
                }
            )
        }

        # socket connecting ssh_proxy to workers
        if (events[[4]]$read) {
            msg = qsys$receive_data()
            message("received: ", msg)
            switch(msg$id,
                "WORKER_UP" = {
                    qsys$send_common_data()
                }
            )
        }
    }

    message("shutting down and cleaning up")
}
