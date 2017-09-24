send = function(sock, data) {
    rzmq::send.socket(sock, data)
}

recv = function(sock, timeout=3L) {
    event = rzmq::poll.socket(list(sock), list("read"), timeout=timeout)
    if (event[[1]]$read)
        rzmq::receive.socket(sock)
    else
        warning(parallel::mccollect(p)[[1]], immediate.=TRUE)
}
