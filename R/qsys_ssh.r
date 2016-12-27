#' LSF scheduler functions
#'
#' Derives from QSys to provide LSF-specific functions
SSH = R6::R6Class("SSH",
    inherit = QSys,

    public = list(
        initialize = function(fun, const, seed) {
            super$initialize()

            ssh_host = "ebi"

            private$listen_socket(6000, 8000) # provides port, master

# ssh -A -R 10080:localhost_or_machine_from:80 user@remote.tld "ssh -g -N -L 80:localhost:10080 localhost"
            local_port = private$port
            restricted_port = 10067
            remote_port = 10068

            # set forward and run ssh.r (send port, master)
            rev_tunnel = sprintf("%i:localhost:%i", restricted_port, local_port)
            remote_net = sprintf("%i:localhost:%i", remote_port, restricted_port)
            rcmd = sprintf("R --no-save --no-restore -e \'clustermq:::ssh(%i)\'", remote_port)
            ssh_cmd = sprintf('ssh -R %s %s "ssh -g -N -L %s localhost %s"',
                               rev_tunnel, ssh_host, remote_net, rcmd)

            # wait for ssh to connect
            message("Waiting for SSH to connect ...")
#            system(ssh_cmd, wait=FALSE)
            message(ssh_cmd)
            msg = rzmq::receive.socket(private$socket)
            if (msg != "ok")
                stop("Establishing connection failed")

            # send common data to ssh
            message("Sending common data ...")
            rzmq::send.socket(private$socket, data = list(fun=fun, const=const, seed=seed))
            msg = rzmq::receive.socket(private$socket)
            if (msg != "ok")
                stop("Sending failed")

            private$set_common_data(fun, const, seed) # later set: url=ssh_master
        },

        submit_job = function(memory=NULL, log_worker=FALSE) {
            if (is.null(private$master))
                stop("Need to call listen_socket() first")

            # get the parent call and evaluate all arguments
            call = match.call()
            evaluated = lapply(call[2:length(call)], function(arg) {
                if (is.call(arg) || is.name(arg))
                    eval(arg, envir=parent.frame(2))
                else
                    arg
            })

            # forward the submit_job call via ssh
            call[2:length(call)] = evaluated
            rzmq::send.socket(private$socket, data = call)

            msg = rzmq::receive.socket(private$socket)
            if (class(msg) == "try-error")
                stop(msg)
        },

        cleanup = function() {
            # leave empty for now
        }
    ),

    private = list(
    ),

    cloneable=FALSE
)
