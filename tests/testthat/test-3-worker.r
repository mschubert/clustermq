context("worker")

has_localhost = has_connectivity("localhost")
context = rzmq::init.context()
socket = rzmq::init.socket(context, "ZMQ_REP")
port = bind_avail(socket, 55000:57000, n_tries=10)
master = paste("tcp://localhost", port, sep=":")

start_worker = function() {
    skip_if_not(has_localhost)
    skip_on_os("windows")
    skip_on_cran()

    p = parallel::mcparallel(worker(master))
    on.exit(tools::pskill(p$pid, tools::SIGKILL))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_UP")
    on.exit(NULL)
    p
}

send_common = function(fun=function(x) x) {
    send(socket, list(id="DO_SETUP", fun=fun, const=list(),
         export=list(), rettype="list", common_seed=1, token="token"))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_READY")
}

shutdown_worker = function(p, worker_active=TRUE) {
    if (worker_active)
        send(socket, list(id="WORKER_STOP"))
    msg = recv(p, socket)
    if (worker_active)
        send(socket, list()) # already shut down, but reset socket state
    testthat::expect_equal(msg$id, "WORKER_DONE")
    testthat::expect_is(msg$time, "proc_time")
    testthat::expect_is(msg$calls, "numeric")
    clean_collect(p)
}

test_that("sending common data", {
    p = start_worker()
    on.exit(tools::pskill(p$pid, tools::SIGKILL))
    send_common()
    shutdown_worker(p)
    on.exit(NULL)
})

test_that("invalid common data", {
    p = start_worker()
    on.exit(tools::pskill(p$pid, tools::SIGKILL))

    send(socket, list(id="DO_SETUP", invalid=TRUE))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_ERROR")

    shutdown_worker(p)
    on.exit(NULL)
})

test_that("common data redirect", {
    p = start_worker()
    on.exit(tools::pskill(p$pid, tools::SIGKILL))

    send(socket, list(id="DO_SETUP", redirect=master))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_UP")

    send_common()
    shutdown_worker(p)
    on.exit(NULL)
})

test_that("do work", {
    p = start_worker()
    on.exit(tools::pskill(p$pid, tools::SIGKILL))
    send_common()

    # should probably also test for error when DO_CHUNK but no chunk provided
    send(socket, list(id="DO_CHUNK", chunk=data.frame(x=5), token="token"))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_READY")
    testthat::expect_equal(msg$result, list(`1`=5))

    shutdown_worker(p)
    on.exit(NULL)
})

test_that("token mismatch", {
    p = start_worker()
    on.exit(tools::pskill(p$pid, tools::SIGKILL))
    send_common()

    # should probably also test for error when DO_CHUNK but no chunk provided
    send(socket, list(id="DO_CHUNK", chunk=data.frame(x=5), token="token2"))
    msg = recv(p, socket)
    testthat::expect_equal(msg$id, "WORKER_ERROR")
    shutdown_worker(p, worker_active=FALSE)

    on.exit(NULL)
})
