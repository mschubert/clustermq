#' Binds an rzmq to an available port in given range
#'
#' @param socket   An rzmq socket object
#' @param range    Numbers to consider (e.g. 6000:8000)
#' @param iface    Interface to listen on
#' @param n_tries  Number of ports to try in range
#' @return         The port the socket is bound to
bind_avail = function(socket, range, iface="tcp://*", n_tries=100) {
    ports = sample(range, n_tries)

    for (i in 1:n_tries) {
        addr = paste(iface, ports[i], sep=":")
        port_found = rzmq::bind.socket(socket, addr)
        if (port_found)
            break
    }

    if (!port_found)
        stop("Could not bind after ", n_tries, " tries")

    ports[i]
}
