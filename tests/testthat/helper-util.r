send = function(sock, data) {
    send_socket(sock, data)
}

recv = function(p, sock, timeout=3L) {
    event = poll_socket(list(sock), timeout=timeout * 1000)
    if (is.null(event))
        return(recv(p, sock, timeout=timeout))
    else if (event[1]) {
        re = receive_multipart(sock)
        if (length(re) == 1)
            re[[1]]
        else
            re
    } else {
        msg = parallel::mccollect(p, wait=FALSE)[[1]][1]
        stop(paste("@bg:", sub("Error in\\s+", "", sub("\n[^$]", "", msg))))
    }
}

has_connectivity = function(host, protocol="tcp") {
    if (length(host) == 0 || nchar(host) == 0)
        return(FALSE)
    context = init_context()
    server = init_socket(context, "ZMQ_REP")
    port = try(bind_avail(server, 55000:57000, n_tries=10))
    if (class(port) == "try-error")
        return(FALSE)
    master = sprintf("%s://%s:%i", protocol, host, port)
    client = init_socket(context, "ZMQ_REQ")
    connect_socket(client, master)
    send_socket(client, data=list(id="test"))
    event = poll_socket(list(server), timeout=500L)
    if (event[1]) {
        msg = receive_socket(server)
        if (msg == "test")
            return(TRUE)
    }
    FALSE
}

ssh_opts = "-oPasswordAuthentication=no -oChallengeResponseAuthentication=no"

has_ssh = function(host) {
    status = system(paste("ssh", ssh_opts, host, "'exit'"), wait=TRUE,
                    ignore.stdout=TRUE, ignore.stderr=TRUE)
    status == 0
}

has_ssh_cmq = function(host) {
    status = system(paste("ssh", ssh_opts, host, "'R -e \"library(clustermq)\"'"),
                    wait=TRUE, ignore.stdout=TRUE, ignore.stderr=TRUE)
    status == 0
}

has_cmq = function(host) {
    status = system("R -e 'library(clustermq)'", wait=TRUE,
                    ignore.stdout=TRUE, ignore.stderr=TRUE)
    status == 0
}
