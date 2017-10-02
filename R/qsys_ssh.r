#' SSH scheduler functions
#'
#' Derives from QSys to provide SSH-specific functions
SSH = R6::R6Class("SSH",
    inherit = QSys,

    public = list(
        initialize = function(data, ...) {
            if (is.null(SSH$host))
                stop("SSH host not set")

            super$initialize(...)
            private$proxy_socket = rzmq::init.socket(private$zmq_context, "ZMQ_REP")
            local_port = bind_avail(private$proxy_socket, 11000:13000)
            remote_port = sample(50000:55000, 2)

            # set forward and run ssh.r (send port, master)
            ctl_tunnel = sprintf("%i:localhost:%i", remote_port[1], local_port)
            job_tunnel = sprintf("%i:localhost:%i", remote_port[2], private$port)
            rcmd = sprintf("R --no-save --no-restore -e \\
                           'clustermq:::ssh_proxy(ctl=%i, job=%i)' > %s 2>&1",
                           remote_port[1], remote_port[2],
                           getOption("clustermq.ssh.log", default="/dev/null"))
            ssh_cmd = sprintf('ssh -f -R %s -R %s %s "%s"',
                              ctl_tunnel, job_tunnel, SSH$host, rcmd)

            # wait for ssh to connect
            message(sprintf("Connecting %s via SSH ...", SSH$host))
            system(ssh_cmd, wait=TRUE, ignore.stdout=TRUE, ignore.stderr=TRUE)

            # Exchange init messages with proxy
            msg = rzmq::receive.socket(private$proxy_socket)
            if (msg$id != "PROXY_UP")
                stop("Establishing connection failed")

            # send common data to ssh
            message("Sending common data ...")
            rzmq::send.socket(private$proxy_socket, data=c(list(id="DO_SETUP"), data))
            msg = rzmq::receive.socket(private$proxy_socket)
            if (msg$id != "PROXY_READY")
                stop("Sending failed")

            self$set_common_data(id="DO_SETUP", redirect=msg$data_url,
                                 token = msg$token)
        },

        submit_jobs = function(n_jobs, template=list(), log_worker=FALSE) {
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
            rzmq::send.socket(private$proxy_socket,
                              data = list(id="PROXY_CMD", exec=call))

            msg = rzmq::receive.socket(private$proxy_socket)
            if (msg$id != "PROXY_CMD" || class(msg$reply) == "try-error")
                stop(msg)
        },

        cleanup = function() {
            rzmq::send.socket(private$proxy_socket, data=list(id="PROXY_STOP"))
            super$cleanup()
        }
    ),

	private = list(
        proxy_socket = NULL
	)
)

# Static method, process scheduler options and return updated object
SSH$setup = function() {
    host = getOption("clustermq.ssh.host")
    if (length(host) == 0) {
        packageStartupMessage("* Option 'clustermq.ssh.host' not set, ",
                "trying to use it will fail")
        packageStartupMessage("--- see: https://github.com/mschubert/clustermq/wiki/SSH")
    } else {
        SSH$host = host
    }
    SSH
}
