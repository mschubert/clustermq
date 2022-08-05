context("worker")

has_localhost = has_connectivity("localhost")
context = init_context()
socket = init_socket(context, "ZMQ_REP")
port = bind_avail(socket, 55000:57000, n_tries=50)
master = paste("tcp://localhost", port, sep=":")

start_worker = function() {
    skip_if_not(has_localhost)
    skip_on_os("windows")
    gc() # be sure to clean up old ZeroMQ handles (zeromq/libzmq/issues/1108)
    p = parallel::mcparallel(worker(master))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_UP")
    p
}

send_common = function(p, fun=function(x) x) {
    send(socket, list(id="DO_SETUP", fun=fun, const=list(), export=list(),
                      rettype="list", pkgs=c(), common_seed=1, token="token"))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_READY")
}

shutdown_worker = function(p, worker_active=TRUE) {
    # note[1]: Peer is already shut down, this is to reset the socket state so
    #   we can connect another client after. Alternative is init a new socket
    #   each time or to use socket opts ZMQ_REQ_CORRELATE and ZMQ_REQ_RELAXED:
    #   https://stackoverflow.com/questions/26915347/zeromq-reset-req-rep-socket-state
    if (worker_active) {
        send(socket, list(id="WORKER_STOP"))
        msg = recv(p, socket)
        send(socket, list()) # [1]
        testthat::expect_equal(msg$id, "WORKER_DONE")
        testthat::expect_is(msg$time, "proc_time")
        testthat::expect_is(msg$calls, "numeric")
    } else
        send(socket, list()) # [1]
    parallel::mccollect(p)
}

test_that("sending common data", {
    p = start_worker()
    send_common(p)
    shutdown_worker(p)
})

test_that("invalid common data", {
    p = start_worker()

    send(socket, list(id="DO_SETUP", invalid=TRUE))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_ERROR")

    shutdown_worker(p)
})

#test_that("common data redirect", {
#    p = start_worker()
#
#    send(socket, list(id="DO_SETUP", redirect=master))
#    msg = recv(p, socket)
#    testthat::expect_equal(msg$id, "WORKER_READY")
#
#    send_common(p)
#    shutdown_worker(p)
#})

test_that("do work", {
    p = start_worker()
    send_common(p)

    # should probably also test for error when DO_CHUNK but no chunk provided
    send(socket, list(id="DO_CHUNK", chunk=data.frame(x=5), token="token"))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_READY")
    testthat::expect_equal(msg$result, list(`1`=5))

    shutdown_worker(p)
})

test_that("token mismatch", {
    p = start_worker()
    send_common(p)

    send(socket, list(id="DO_CHUNK", chunk=data.frame(x=5), token="token2"))
    msg = recv(p, socket)
    testthat::expect_equal(msg[[1]]$id, "WORKER_ERROR")

    shutdown_worker(p, worker_active=FALSE)
})

test_that("custom call", {
    p = start_worker()
    send_common(p)

    send(socket, list(id="DO_CALL", expr=quote(x*2), env=list(x=4), ref=1L))
    msg = recv(p, socket)

    testthat::expect_equal(msg$id, "WORKER_READY")
    testthat::expect_equal(msg$result, 8)
    testthat::expect_equal(msg$ref, 1L)

    shutdown_worker(p)
})
