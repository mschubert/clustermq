#' SSH proxy for different schedulers
#'
#' Do not call this manually, the SSH qsys will do that
#'
#' @param master_port  The master address (tcp://ip:port)
ssh_proxy = function(master_port) {
    # network forwarding most likely disabled, so set up local SSH forward
    net_port = sample(8000:9999, 1)
    cmd = sprintf("ssh -g -N -f -L %i:localhost:%i localhost", net_port, master_port)
    system(cmd, wait=TRUE)
    on.exit(system(sprintf("kill $(pgrep -f '%s')", cmd)))

    master = sprintf("tcp://%s:%i", Sys.info()[['nodename']], net_port)
    message("master set up:", master)

    # connect to master
    context = rzmq::init.context()
    socket = rzmq::init.socket(context, "ZMQ_REQ")
    rzmq::connect.socket(socket, master)
    rzmq::send.socket(socket, data=list(id=SSH_UP))
    message("socket init & sent first data")

    # receive common data
    msg = rzmq::receive.socket(socket)
    message("received common data:", utils::head(msg$fun), names(msg$const), msg$seed)
    qsys = qsys$new(fun=msg$fun, const=msg$const, seed=msg$seed)
    qsys$set_master(master)
    rzmq::send.socket(socket, data=list(id=SSH_READY, proxy=qsys$url))
    message("sent SSH_READY to master")

    while(TRUE) {
        events = rzmq::poll.socket(list(socket, qsys$poll),
                                   list("read", "read"),
                                   timeout=-1L)

        if (events[[1]]$read) {
            msg = rzmq::receive.socket(socket)
            message("received: ", msg)
            switch(msg$id,
                SSH_NOOP = {
                    Sys.sleep(1)
                    rzmq::send.socket(socket, data=list(id="SSH_NOOP"))
                    next
                },
                SSH_CMD = {
                    reply = try(eval(msg$exec))
                    rzmq::send.socket(socket, data=list(id="SSH_CMD", reply=reply))
                },
                SSH_STOP = {
                    break
                }
            )
        }

        if (events[[2]]$read) {
            msg = qsys$receive_data()
            message("received: ", msg)
            switch(msg$id,
                WORKER_UP = {
                    qsys$send_common_data()
                }
            )
        }
    }

    message("shutting down and cleaning up")
}
