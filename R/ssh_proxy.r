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
    rzmq::send.socket(socket, data="ok")
    message("socket init & sent first data")

    # receive common data
    msg = rzmq::receive.socket(socket)
    message("received common data:", head(msg$fun), names(msg$const), msg$seed)
    qsys = qsys$new(fun=msg$fun, const=msg$const, seed=msg$seed, master=master)
    rzmq::send.socket(socket, data="ok")
    message("sent ready to accept jobs")

    while(TRUE) {
        msg = rzmq::receive.socket(socket)
        message("received:", msg)
#        stopifnot(msg[[1]] %in% c("submit_job", "send_common_data", "cleanup"))

        # if the master checks if we are alive, delay next msg
        if (length(msg) == 0) {
            Sys.sleep(1)
            rzmq::send.socket(socket, data=list())
            next
        }

        reply = try(eval(msg))
        rzmq::send.socket(socket, data=reply)

        if (msg[[1]] == "cleanup") # this is never reached (just killed on disc)
            break
    }
}
