#' SSH proxy for different schedulers
#'
#' Do not call this manually, the SSH qsys will do that
#'
#' @param master_port  The port for SSH reverse tunnel to master
ssh_proxy = function(master_port) {
    context = rzmq::init.context()

    # get address of SSH tunnel
    ssh_tunnel = sprintf("tcp://localhost:%i", master_port)
    message("SSH tunnel listening at: ", ssh_tunnel)
    fwd_out = rzmq::init.socket(context, "ZMQ_XREQ")
    re = rzmq::connect.socket(fwd_out, ssh_tunnel)
    if (!re)
        stop("failed to connect to SSH tunnel")

    # set up local network forward to SSH tunnel
    # this could be done with ssh -R -g, but is disabled by default
    fwd_in = rzmq::init.socket(context, "ZMQ_XREP")
    net_port = bind_avail(fwd_in, 8000:9999)
    net_fwd = sprintf("tcp://%s:%i", Sys.info()[['nodename']], net_port)
    message("forwarding local network from: ", net_fwd)

    # connect to master
    socket = rzmq::init.socket(context, "ZMQ_REQ")
    rzmq::connect.socket(socket, ssh_tunnel)
    rzmq::send.socket(socket, data=list(id="SSH_UP"))
    message("sent SSH_UP to master via tunnel")

    # receive common data
    msg = rzmq::receive.socket(socket)
    message("received common data:",
            utils::head(msg$fun), names(msg$const), names(msg$export), msg$seed)
    qsys = qsys$new(fun=msg$fun, const=msg$const, export=msg$export, seed=msg$seed)
    qsys$set_master(net_fwd)
    rzmq::send.socket(socket, data=list(id="SSH_READY", proxy=qsys$url))
    message("sent SSH_READY to master via tunnel")

    while(TRUE) {
        events = rzmq::poll.socket(list(fwd_in, fwd_out, socket, qsys$poll),
                                   rep(list("read"), 4),
                                   timeout=-1L)

        # forwarding messages between workers and master
        if (events[[1]]$read)
            rzmq::send.multipart(fwd_out, rzmq::receive.multipart(fwd_in))
        if (events[[2]]$read)
            rzmq::send.multipart(fwd_in, rzmq::receive.multipart(fwd_out))

        # socket connecting ssh_proxy to master
        if (events[[3]]$read) {
            msg = rzmq::receive.socket(socket)
            message("received: ", msg)
            switch(msg$id,
                "SSH_NOOP" = {
                    Sys.sleep(1)
                    rzmq::send.socket(socket, data=list(id="SSH_NOOP"))
                    next
                },
                "SSH_CMD" = {
                    reply = try(eval(msg$exec))
                    rzmq::send.socket(socket, data=list(id="SSH_CMD", reply=reply))
                },
                "SSH_STOP" = {
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
