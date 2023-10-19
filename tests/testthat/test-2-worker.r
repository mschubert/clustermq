context("worker usage")

test_that("connect to invalid endpoint errors", {
    w = methods::new(CMQWorker)
    expect_error(w$connect("tcp://localhost:12345", 0L))
    w$close()
})

test_that("recv without pending workers errors before timeout", {
    m = methods::new(CMQMaster)
    addr = m$listen("inproc://endpoint")
    expect_error(m$recv(-1L))
    m$close(500L)
})

test_that("recv timeout works", {
    m = methods::new(CMQMaster)
    addr = m$listen("inproc://endpoint")
    m$add_pending_workers(1L)
    expect_error(m$recv(0L))
    m$close(500L)
})

test_that("worker evaluation", {
    m = methods::new(CMQMaster)
    w = methods::new(CMQWorker, m$context())
    addr = m$listen("inproc://endpoint")
    m$add_pending_workers(1L)
    w$connect(addr, 500L)

    m$recv(500L)
    m$send(expression(5 * 2))
    status = w$process_one()
    result = m$recv(500L)

    expect_true(status)
    expect_equal(result, 10)

    w$close()
    m$close(500L)
})

test_that("export variable to worker", {
    m = methods::new(CMQMaster)
    w = methods::new(CMQWorker, m$context())
    addr = m$listen("inproc://endpoint")
    m$add_pending_workers(1L)
    w$connect(addr, 500L)

    m$add_env("x", 3)
    m$recv(500L)
    m$send(expression(5 + x))
    status = w$process_one()
    result = m$recv(500L)
    expect_true(status)
    expect_equal(result, 8)

    m$add_env("x", 5)
    m$send(expression(5 + x))
    status = w$process_one()
    result = m$recv(500L)
    expect_true(status)
    expect_equal(result, 10)

    w$close()
    m$close(500L)
})

test_that("load package on worker", {
    m = methods::new(CMQMaster)
    w = methods::new(CMQWorker, m$context())
    addr = m$listen("inproc://endpoint")
    m$add_pending_workers(1L)
    w$connect(addr, 500L)

    m$add_pkg("parallel")

    m$recv(500L)
    m$send(expression(splitIndices(1, 1)[[1]]))
    status = w$process_one()
    result = m$recv(500L)

    expect_true(status)
    expect_equal(result, 1)

    w$close()
    m$close(500L)
})

test_that("errors are sent back to master", {
    skip("this works interactively but evaluates the error on testthat")

    m = methods::new(CMQMaster)
    w = methods::new(CMQWorker, m$context())
    addr = m$listen("inproc://endpoint")
    m$add_pending_workers(1L)
    w$connect(addr, 500L)

    m$recv(500L)
    m$send(expression(stop("errmsg")))
    status = w$process_one()
    result = m$recv(500L)

    expect_true(status)
    expect_true(inherits(result, c("condition", "worker_error")))

    w$close()
    m$close(500L)
})

test_that("worker R API", {
    skip_on_os("windows")
    skip_if_not(has_connectivity("127.0.0.1")) # -> this or inproc w/ passing context

    m = methods::new(CMQMaster)
    addr = m$listen("tcp://127.0.0.1:*")
    m$add_pending_workers(1L)
#    addr = m$listen("inproc://endpoint") # mailbox.cpp assertion error

    p = parallel::mcparallel(worker(addr))
    expect_null(m$recv(1000L))
    m$send(expression(5 + 1))
    res = m$recv(500L)
    expect_equal(res[[1]], 6)

    m$send_shutdown()
    pc = parallel::mccollect(p, wait=TRUE, timeout=0.5)
    expect_equal(pc[[1]], NULL)
    m$close(500L)
})

test_that("communication with two workers", {
    skip_on_os("windows")
    skip_if_not(has_connectivity("127.0.0.1"))

    m = methods::new(CMQMaster)
    addr = m$listen("tcp://127.0.0.1:*")
    m$add_pending_workers(2L)
    w1 = parallel::mcparallel(worker(addr))
    w2 = parallel::mcparallel(worker(addr))

    expect_null(m$recv(1000L)) # worker 1 up
    m$send(expression({ Sys.sleep(0.5); 5 + 2 }))
    expect_null(m$recv(500L)) # worker 2 up
    m$send(expression({ Sys.sleep(0.5); 3 + 1 }))
    r1 = m$recv(1000L)
    m$send_shutdown()
    r2 = m$recv(1000L)
    m$send_shutdown()
    expect_equal(sort(c(r1, r2)), c(4,7))

    coll1 = parallel::mccollect(w1, wait=TRUE, timeout=0.5)
    expect_equal(names(coll1), as.character(w1$pid))
    coll2 = parallel::mccollect(w2, wait=TRUE, timeout=0.5)
    expect_equal(names(coll2), as.character(w2$pid))

    m$close(500L)
})
