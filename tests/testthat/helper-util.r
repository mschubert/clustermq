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

ssh_opts = "-oPasswordAuthentication=no -oChallengeResponseAuthentication=no"

has_ssh = function(host) {
    status = system(paste("ssh", ssh_opts, host, "'exit'"), wait=TRUE,
                    ignore.stdout=TRUE, ignore.stderr=TRUE)
    status == 0
}

has_ssh_cmq = function(host) {
    status = suppressWarnings(
        system(paste("ssh", ssh_opts, host, "'R -e \"library(clustermq)\"'"),
               wait=TRUE, ignore.stdout=TRUE, ignore.stderr=TRUE))
    status == 0
}

has_cmq = function(host) {
    status = system("R -e 'library(clustermq)'", wait=TRUE,
                    ignore.stdout=TRUE, ignore.stderr=TRUE)
    status == 0
}
