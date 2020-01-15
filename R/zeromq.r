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

        listen2 = function(address, socket_type="ZMQ_REP", sid="default")
            private$zmq$listen2(address, socket_type, sid),

        listen = function(range=6000:9999, iface="tcp://*", n_tries=100,
                          socket_type="ZMQ_REP", sid="default")
            private$zmq$listen(head(sample(range), n_tries), iface, socket_type, sid),

        connect = function(address, socket_type="ZMQ_REQ", sid="default")
            private$zmq$connect(address, socket_type, sid),

        disconnect = function(sid="default")
            private$zmq$disconnect(sid),

        send = function(data, sid="default", dont_wait=FALSE, send_more=FALSE)
            private$zmq$send(data, sid, dont_wait, send_more),

        receive = function(sid="default", dont_wait=FALSE, unserialize=TRUE)
            private$zmq$receive(sid, dont_wait, unserialize),

        poll = function(sid="default", timeout=-1L)
            private$zmq$poll(sid, timeout)
    ),

    private = list(
        zmq = NULL
    ),

    cloneable = FALSE
)
