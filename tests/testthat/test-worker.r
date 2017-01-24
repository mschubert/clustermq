context("worker")

context = rzmq::init.context()
socket = rzmq::init.socket(context, "ZMQ_REP")
rzmq::bind.socket(socket, "tcp://*:55443")

test_that("control flow", {
	worker_id = "1"
	p = parallel::mcparallel(worker(worker_id, "tcp://localhost:55443", 1024))

	msg = rzmq::receive.socket(socket)
	testthat::expect_equal(msg$id, "WORKER_UP")

	rzmq::send.socket(socket, list(fun=function(x) x, const=list(), seed=1))

	msg = rzmq::receive.socket(socket)
	testthat::expect_equal(msg$id, "WORKER_READY")

	rzmq::send.socket(socket, list(id="WORKER_STOP"))

	msg = rzmq::receive.socket(socket)
	testthat::expect_equal(msg$id, "WORKER_DONE")
	testthat::expect_equal(msg$worker_id, worker_id)
	testthat::expect_is(msg$time, "proc_time")
	testthat::expect_is(msg$calls, "numeric")

	parallel::mccollect(p)
})
