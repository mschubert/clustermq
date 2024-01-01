#' SSH scheduler functions
#'
#' Derives from QSys to provide SSH-specific functions
#'
#' @keywords internal
SSH = R6::R6Class("SSH",
    inherit = QSys,

    public = list(
        initialize = function(addr, n_jobs, ..., master,
                              ssh_host = getOption("clustermq.ssh.host"),
                              ssh_log = getOption("clustermq.ssh.log"),
                              template = getOption("clustermq.template", "SSH"),
                              verbose = TRUE) {
            if (is.null(ssh_host))
                stop("Option 'clustermq.ssh.host' required for SSH but not set")
            if (!grepl("^tcp://", addr))
                stop("SSH QSys must connect via tcp:// not ", sQuote(addr))

            super$initialize(addr=addr, master=master, template=template)
            private$template = paste(trimws(readLines(textConnection(private$template))), collapse=" ")

            # set forward and run ssh.r (send port, master)
            opts = private$fill_options(ssh_log=ssh_log, ssh_host=ssh_host)
            ssh_cmd = fill_template(private$template, opts,
                required=c("local_port", "ssh.hpc_fwd_port", "ssh_host"))

            # wait for ssh to connect
            message(sprintf("Connecting to %s via SSH ...", sQuote(ssh_host)))
            system(ssh_cmd, wait=TRUE, ignore.stdout=TRUE, ignore.stderr=TRUE)

            master$add_pending_workers(n_jobs)
            args = c(list(...), list(n_jobs=n_jobs))
            init_timeout = getOption("clustermq.ssh.timeout", 10)
            tryCatch(private$master$proxy_submit_cmd(args, init_timeout*1000),
                error = function(e) {
                    if (grepl("timed out", conditionMessage(e))) {
                        stop("Remote R process did not respond after ",
                             init_timeout, " seconds. Check your SSH server log.")
                    } else stop(e)
            })

            private$workers_total = args$n_jobs
        },

        cleanup = function(success, timeout) {
            private$finalize()
            TRUE
        }
    ),

    private = list(
        ssh_proxy_running = TRUE,

        fill_options = function(...) {
            args = list(...)
            args$local_port = sub(".*:", "", private$addr)
            args$ssh.hpc_fwd_port = getOption("clustermq.ssh.hpc_fwd_port", sample(50000:55000, 1))
            utils::modifyList(private$defaults, args)
        },

        finalize = function(quiet = self$workers_running == 0) {
#            if (private$ssh_proxy_running) {
#                private$zmq$send(
#                    list(id="PROXY_STOP", finalize=!private$is_cleaned_up),
#                    "proxy"
#                )
#            }
            private$ssh_proxy_running = FALSE
        }
    )
)
