context("worker")

context = rzmq::init.context()
socket = rzmq::init.socket(context, "ZMQ_REP")
port = try(bind_avail(socket, 55000:57000, n_tries=10))
master = paste("tcp://localhost", port, sep=":")
Sys.sleep(0.5)

start_worker = function() {
    skip_on_os("windows")

    if (class(port) == "try-error")
        skip("Failed to bind port")

    p = parallel::mcparallel(worker(master))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_UP")
    p
}

send_common = function(fun=function(x) x) {
    send(socket, list(id="DO_SETUP", fun=fun, const=list(),
         export=list(), common_seed=1, token="token"))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_READY")
}

shutdown_worker = function(p) {
    send(socket, list(id="WORKER_STOP"))
    msg = recv(p, socket)
    send(socket, list()) # already shut down
    testthat::expect_equal(msg$id, "WORKER_DONE")
    testthat::expect_is(msg$time, "proc_time")
    testthat::expect_is(msg$calls, "numeric")
    clean_collect(p)
}

test_that("sending common data", {
    p = start_worker()
    send_common()
    shutdown_worker(p)
})

test_that("invalid common data", {
    p = start_worker()

    send(socket, list(id="DO_SETUP", invalid=TRUE))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_ERROR")

    shutdown_worker(p)
})

test_that("common data redirect", {
    p = start_worker()

    send(socket, list(id="DO_SETUP", redirect=master))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_UP")

    send_common()
    shutdown_worker(p)
})

test_that("do work", {
    p = start_worker()
    send_common()

    # should probably also test for error when DO_CHUNK but no chunk provided
    send(socket, list(id="DO_CHUNK", chunk=data.frame(x=5), token="token"))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_READY")
    testthat::expect_equal(msg$result, list(`1`=5))

    shutdown_worker(p)
})

test_that("token mismatch", {
    p = start_worker()
    send_common()

    # should probably also test for error when DO_CHUNK but no chunk provided
    send(socket, list(id="DO_CHUNK", chunk=data.frame(x=5), token="token2"))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_ERROR")

    shutdown_worker(p)
})
