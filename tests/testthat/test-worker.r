context("worker")

context = rzmq::init.context()
socket = rzmq::init.socket(context, "ZMQ_REP")
rzmq::bind.socket(socket, "tcp://*:55443")
Sys.sleep(0.5)

start_worker = function(id="1", url="tcp://localhost:55443") {
    skip_on_os("windows")

    p = parallel::mcparallel(worker(id, url, 1024))
    msg = rzmq::receive.socket(socket)
    testthat::expect_equal(msg$id, "WORKER_UP")
    p
}

send_common = function(fun=function(x) x) {
    rzmq::send.socket(socket, list(fun=fun, const=list(), export=list(), seed=1))
    msg = rzmq::receive.socket(socket)
    testthat::expect_equal(msg$id, "WORKER_READY")
}

shutdown_worker = function(p, id="1") {
    rzmq::send.socket(socket, list(id="WORKER_STOP"))
    msg = rzmq::receive.socket(socket)
#    rzmq::disconnect.socket(socket)
    rzmq::send.socket(socket, list()) # already shut down
    testthat::expect_equal(msg$id, "WORKER_DONE")
    testthat::expect_equal(msg$worker_id, id)
    testthat::expect_is(msg$time, "proc_time")
    testthat::expect_is(msg$calls, "numeric")
    parallel::mccollect(p)
    Sys.sleep(0.5)
}

test_that("control flow", {
    p = start_worker()
    send_common()
    shutdown_worker(p)
})

test_that("common data redirect", {
    p = start_worker()

    rzmq::send.socket(socket, list(redirect="tcp://localhost:55443"))
    msg = rzmq::receive.socket(socket)
    testthat::expect_equal(msg$id, "WORKER_UP")

    send_common()
    shutdown_worker(p)
})

test_that("do work", {
    p = start_worker()
    send_common()

    #TODO: should probably test for error when DO_CHUNK but no chunk provided
    rzmq::send.socket(socket, list(id="DO_CHUNK", chunk=data.frame(x=5)))
    msg = rzmq::receive.socket(socket)
    testthat::expect_equal(msg$id, "WORKER_READY")
    testthat::expect_equal(msg$result, list(`1`=5))

    shutdown_worker(p)
})
