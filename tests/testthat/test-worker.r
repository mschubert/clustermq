context("worker")

context = rzmq::init.context()
socket = rzmq::init.socket(context, "ZMQ_REP")
rzmq::bind.socket(socket, "tcp://*:55443")

start_worker = function(id="1", url="tcp://localhost:55443") {
	p = parallel::mcparallel(worker(id, url, 1024))
	msg = rzmq::receive.socket(socket)
	testthat::expect_equal(msg$id, "WORKER_UP")
    p
}

send_common = function() {
	rzmq::send.socket(socket, list(fun=function(x) x, const=list(), seed=1))
	msg = rzmq::receive.socket(socket)
	testthat::expect_equal(msg$id, "WORKER_READY")
}

shutdown_worker = function(p, id="1") {
	rzmq::send.socket(socket, list(id="WORKER_STOP"))
	msg = rzmq::receive.socket(socket)
    rzmq::send.socket(socket, "invalid") # already shut down
	testthat::expect_equal(msg$id, "WORKER_DONE")
	testthat::expect_equal(msg$worker_id, id)
	testthat::expect_is(msg$time, "proc_time")
	testthat::expect_is(msg$calls, "numeric")
	parallel::mccollect(p)
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
