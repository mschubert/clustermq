#' SSH scheduler functions
#'
#' Derives from QSys to provide SSH-specific functions
#'
#' @keywords internal
SSH = R6::R6Class("SSH",
    inherit = QSys,

    public = list(
        initialize = function(data, ...,
                              ssh_host = getOption("clustermq.ssh.host"),
                              ssh_log = getOption("clustermq.ssh.log"),
                              template = getOption("clustermq.template", "SSH")) {
            if (is.null(ssh_host))
                stop("Option 'clustermq.ssh.host' required for SSH but not set")

            super$initialize(..., template=template)
            private$proxy_socket = rzmq::init.socket(private$zmq_context, "ZMQ_REP")

            # set forward and run ssh.r (send port, master)
            opts = private$fill_options(ssh_log=ssh_log, ssh_host=ssh_host)
            ssh_cmd = private$fill_template(opts)

            # wait for ssh to connect
            message(sprintf("Connecting %s via SSH ...", ssh_host))
            system(ssh_cmd, wait=TRUE, ignore.stdout=TRUE, ignore.stderr=TRUE)

            # Exchange init messages with proxy
            init_timeout = getOption("clustermq.ssh.timeout", 5)
            poll = rzmq::poll.socket(list(private$proxy_socket), list("read"),
                                     timeout=init_timeout)
            if (!poll[[1]]$read)
                stop("Remote R process did not respond after ",
                     init_timeout, " seconds. ",
                     "Check your SSH server log.")
            msg = rzmq::receive.socket(private$proxy_socket)
            if (msg$id != "PROXY_UP")
                stop("Expected PROXY_UP, received ", sQuote(msg$id))

            # send common data to ssh
            message("Sending common data ...")
            rzmq::send.socket(private$proxy_socket, data=c(list(id="DO_SETUP"), data))
            msg = rzmq::receive.socket(private$proxy_socket)
            if (msg$id != "PROXY_READY")
                stop("Expected PROXY_READY, received ", sQuote(msg$id))

            self$set_common_data(id="DO_SETUP", redirect=msg$data_url,
                                 token = msg$token)
        },

        submit_jobs = function(...) {
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
            call[[1]] = quote(qsys$submit_jobs) #FIXME: only works bc 'qsys' in ssh_proxy
            call[2:length(call)] = evaluated
            rzmq::send.socket(private$proxy_socket,
                              data = list(id="PROXY_CMD", exec=call))

            msg = rzmq::receive.socket(private$proxy_socket)
            if (msg$id != "PROXY_CMD" || class(msg$reply) == "try-error")
                stop(msg)

            private$workers_total = list(...)[["n_jobs"]] #TODO: find cleaner way to handle this
        },

        cleanup = function(quiet=FALSE) {
            success = super$cleanup(quiet=quiet)
            self$finalize()
            success
        },

        finalize = function(quiet = self$workers_running == 0) {
            #TODO: should we handle this with PROXY_CMD for break (and finalize if req'd)??
            if (private$ssh_proxy_running) {
                rzmq::send.socket(private$proxy_socket,
                      data=list(id="PROXY_STOP", finalize=!private$is_cleaned_up))
                private$ssh_proxy_running = FALSE
            }
        }
    ),

	private = list(
        proxy_socket = NULL,
        ssh_proxy_running = TRUE,

        fill_options = function(ssh_host, ...) {
            values = utils::modifyList(private$defaults,
                                       list(ssh_host=ssh_host, ...))

            #TODO: let user define ports in private$defaults here and respect them
            remote = sample(50000:55000, 2)
            values$ssh_host = ssh_host
            values$local_port = bind_avail(private$proxy_socket, 11000:13000)
            values$ctl_port = remote[1]
            values$job_port = remote[2]
            values$fwd_port = private$port
            values
        }
	)
)
