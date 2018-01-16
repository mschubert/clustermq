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
