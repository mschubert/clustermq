send = function(sock, data) {
    rzmq::send.socket(sock, data)
}

recv = function(p, sock, timeout=3L) {
    event = rzmq::poll.socket(list(sock), list("read"), timeout=timeout)
    if (event[[1]]$read)
        rzmq::receive.socket(sock)
    else
        clean_collect(p)
}

clean_collect = function(p, timeout=5L) {
    re = parallel::mccollect(p, wait=FALSE, timeout=timeout)

    if (is.null(re)) {
        # if timeout is reached without results
        tools::pskill(p$pid)
        stop("Unclean worker shutdown")
    }

    invisible(re)
}

has_connectivity = function(host, protocol="tcp") {
    context = rzmq::init.context()
    server = rzmq::init.socket(context, "ZMQ_REP")
    port = try(bind_avail(server, 55000:57000, n_tries=10))
    if (class(port) == "try-error")
        return(FALSE)
    master = sprintf("%s://%s:%i", protocol, host, port)
    client = rzmq::init.socket(context, "ZMQ_REQ")
    rzmq::connect.socket(client, master)
    rzmq::send.socket(client, data=list(id="test"))
    event = rzmq::poll.socket(list(server), list("read"), timeout=1L)
    if (event[[1]]$read) {
        msg = rzmq::receive.socket(server)
        if (msg == "test")
            return(TRUE)
    }
    FALSE
}
