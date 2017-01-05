#' SSH proxy for different schedulers
#'
#' Do not call this manually, the SSH qsys will do that
#'
#' @param master_port  The master address (tcp://ip:port)
ssh_proxy = function(master_port) {
    # network forwarding most likely disabled, so set up local SSH forward
    net_port = sample(8000:9999, 1)
    system(sprintf("ssh -g -N -f -L %i:localhost:%i localhost", net_port, master_port))
    master = sprintf("tcp://%s:%i", Sys.info()[['nodename']], net_port)

    # connect to master
    context = rzmq::init.context()
    socket = rzmq::init.socket(context, "ZMQ_REQ")
    rzmq::connect.socket(socket, master)
    rzmq::send.socket(socket, data="ok")

    # receive common data
    msg = rzmq::receive.socket(socket)
    qsys = qsys$new(fun=msg$fun, const=msg$const, seed=msg$seed, master=master)
    rzmq::send.socket(socket, data="ok")

    while(TRUE) {
        msg = rzmq::receive.socket(socket)
#        stopifnot(msg[[1]] %in% c("submit_job", "send_common_data", "cleanup"))

        # if the master checks if we are alive, delay next msg
        if (is.null(msg))
            Sys.sleep(1)

        reply = try(eval(msg))
        rzmq::send.socket(socket, data=reply)

        if (msg[[1]] == "cleanup")
            break
    }
}
