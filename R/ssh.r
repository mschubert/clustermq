#' SSH proxy for different schedulers
#'
#' Do not call this manually, the SSH qsys will do that
#'
#' @param master     The master address (tcp://ip:port)
ssh = function(master) {
    # connect to master
    context = rzmq::init.context()
    socket = rzmq::init.socket(context, "ZMQ_REQ")
    rzmq::connect.socket(socket, master)
    rzmq::send.socket(socket, data="ok")

    # receive common data
    msg = rzmq::receive.socket(socket)
    qsys = qsys$new(fun=msg$fun, const=msg$const, seed=msg$seed)
    rzmq::send.socket(socket, data="ok")

    while(TRUE) {
        msg = rzmq::receive.socket(socket)
        stopifnot(msg[[1]] %in% c("submit_job", "send_common_data", "cleanup"))

        reply = try(eval(msg, envir=qsys))
        rzmq::send.socket(socket, data=reply)

        if (msg[[1]] == "cleanup")
            break
    }
}
