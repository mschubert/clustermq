#' SSH scheduler functions
#'
#' Derives from QSys to provide SSH-specific functions
#'
#' @keywords internal
SSH = R6::R6Class("SSH",
    inherit = QSys,

    public = list(
        initialize = function(addr, ...,
                              ssh_host = getOption("clustermq.ssh.host"),
                              ssh_log = getOption("clustermq.ssh.log"),
                              template = getOption("clustermq.template", "SSH")) {
            if (is.null(ssh_host))
                stop("Option 'clustermq.ssh.host' required for SSH but not set")

            super$initialize(addr=addr, ..., template=template)

            # set forward and run ssh.r (send port, master)
            opts = private$fill_options(ssh_log=ssh_log, ssh_host=ssh_host)
            ssh_cmd = fill_template(private$template, opts,
                required=c("ctl_port", "local_port", "job_port", "fwd_port", "ssh_host"))

            # wait for ssh to connect
            message(sprintf("Connecting %s via SSH ...", ssh_host))
            system(ssh_cmd, wait=TRUE, ignore.stdout=TRUE, ignore.stderr=TRUE)
        },

        submit_jobs = function(..., verbose=TRUE) {
            args = list(...)
            init_timeout = getOption("clustermq.ssh.timeout", 10)
            tryCatch(private$mater$proxy_submit_cmd(args, init_timeout*1000),
                error = function(e) stop("Remote R process did not respond after ",
                    init_timeout, " seconds. Check your SSH server log."))

            private$workers_total = list(...)[["n_jobs"]] #TODO: find cleaner way to handle this
        },

        cleanup = function(quiet=FALSE) {
            success = super$cleanup(quiet=quiet)
            self$finalize()
            success
        }
    ),

	private = list(
        ssh_proxy_running = TRUE,

        fill_options = function(ssh_host, ...) {
            values = utils::modifyList(private$defaults,
                                       list(ssh_host=ssh_host, ...))

            #TODO: let user define ports in private$defaults here and respect them
            remote = sample(50000:55000, 2)
            values$ssh_host = ssh_host
            bound = private$zmq$listen(sid="proxy")
            values$local_port = sub(".*:", "", bound)
            values$ctl_port = remote[1]
            values$job_port = remote[2]
            values$fwd_port = private$port
            values
        },

        finalize = function(quiet = self$workers_running == 0) {
            #TODO: should we handle this with PROXY_CMD for break (and finalize if req'd)??
            if (private$ssh_proxy_running) {
                private$zmq$send(
                    list(id="PROXY_STOP", finalize=!private$is_cleaned_up),
                    "proxy"
                )
                private$ssh_proxy_running = FALSE
            }
        }
	)
)
