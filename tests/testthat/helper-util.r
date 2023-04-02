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
