loadModule("zmq", TRUE) # ZeroMQ_raw C++ class

#' Wrap C++ Rcpp module in R6 to get reliable argument matching
#'
#' This is an R6 wrapper of the C++ class in order to support R argument
#' matching. Ideally, Rcpp will at some point support this natively and this
#' file will no longer be necessary. Until then, it causes redundancy with
#' zeromq.cpp, but this is a small inconvenience and much less error-prone than
#' only relying on positional arguments.
ZeroMQ = R6::R6Class("ZeroMQ",
    public = list(
        initialize = function()
            private$zmq = new(ZeroMQ_raw),

#        finalize = function()
#            private$zmq$destroy(),

        listen = function(address, socket_type="ZMQ_REP")
            private$zmq$listen(socket_type, address),

        connect = function(address, socket_type="ZMQ_REQ")
            private$zmq$connect(socket_type, address),

        disconnect = function()
            private$zmq$disconnect(),

        send = function(data, dont_wait=FALSE, send_more=FALSE)
            private$zmq$send(data, dont_wait, send_more),

        receive = function(dont_wait=FALSE, unserialize=TRUE)
            private$zmq$receive(dont_wait, unserialize),

        poll = function(timeout=-1L)
            private$zmq$poll(timeout)
    ),

    private = list(
        zmq = NULL
    ),

    cloneable = FALSE
)
