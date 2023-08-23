loadModule("cmq_master", TRUE) # CMQMaster C++ class

#' Class for basic queuing system functions
#'
#' Provides the basic functions needed to communicate between machines
#' This should abstract most functions of rZMQ so the scheduler
#' implementations can rely on the higher level functionality
#'
#' @keywords internal
QSys = R6::R6Class("QSys",
    public = list(
        # Create a class instance
        #
        # Initializes ZeroMQ and sets and sets up our primary communication socket
        #
        # @param addr    Vector of possible addresses to bind
        # @param bind    Whether to bind 'addr' or just refer to it
        initialize = function(addr, master, template=NULL) {
            private$master = master
            private$addr = addr
            private$port = as.integer(sub(".*:", "", addr))

            if (!is.null(template)) {
                if (!file.exists(template))
                    template = system.file(paste0(template, ".tmpl"),
                                           package="clustermq", mustWork=TRUE)
                if (file.exists(template))
                    private$template = readChar(template, file.info(template)$size)
                else
                    stop("Template file does not exist: ", sQuote(template))
            }
            private$defaults = getOption("clustermq.defaults", list())
        },

        n = function() private$workers_total
    ),

    private = list(
        master = NULL,
        addr = NULL,
        port = NULL,
        template = NULL,
        workers_total = NULL,
        defaults = list(),

        fill_options = function(...) {
            values = utils::modifyList(private$defaults, list(...))
            values$master = private$addr
            if (grepl("CMQ_AUTH", private$template)) {
                # note: auth will be obligatory in the future and this check will
                #   be removed (i.e., filling will fail if no field in template)
                values$auth = paste(sample(letters, 5, TRUE), collapse="")
            } else {
                values$auth = NULL
                warning("Add 'CMQ_AUTH={{ auth }}' to template to enable socket authentication",
                        immediate.=TRUE)
            }
            if (!"job_name" %in% names(values))
                values$job_name = paste0("cmq", private$port)
            private$workers_total = values$n_jobs
            values
        }
    ),

    cloneable = FALSE
)
