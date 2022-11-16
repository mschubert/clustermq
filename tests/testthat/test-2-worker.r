context("worker usage")

test_that("timeouts are triggered correctly", {
    m = methods::new(CMQMaster)
    addr = m$listen("inproc://endpoint")
    expect_error(m$recv(0L))
    m$close()

# connection timeout not working (needs ZMQ_RECONNECT_STOP_CONN_REFUSED in draft)
#    w = methods::new(CMQWorker)
#    expect_error(w$connect("tcp://localhost:12345", 0L))
#    w$close()
})

test_that("worker evaluation", {
    m = methods::new(CMQMaster)
    w = methods::new(CMQWorker, m$context())
    addr = m$listen("inproc://endpoint")
    w$connect(addr, 0L)

    m$recv(0L)
    m$send(expression(5 * 2), TRUE)
    status = w$process_one()
    result = m$recv(0L)

    expect_true(status)
    expect_equal(result, 10)

    w$close()
    m$close()
})

test_that("export variable to worker", {
    m = methods::new(CMQMaster)
    w = methods::new(CMQWorker, m$context())
    addr = m$listen("inproc://endpoint")
    w$connect(addr, 0L)

    m$add_env("x", 3)
    m$recv(0L)
    m$send(expression(5 + x), TRUE)
    status = w$process_one()
    result = m$recv(0L)
    expect_true(status)
    expect_equal(result, 8)

    m$add_env("x", 5)
    m$send(expression(5 + x), TRUE)
    status = w$process_one()
    result = m$recv(0L)
    expect_true(status)
    expect_equal(result, 10)

    w$close()
    m$close()
})

test_that("load package on worker", {
    m = methods::new(CMQMaster)
    w = methods::new(CMQWorker, m$context())
    addr = m$listen("inproc://endpoint")
    w$connect(addr, 0L)

    m$add_pkg("parallel")

    m$recv(0L)
    m$send(expression(splitIndices(1, 1)[[1]]), TRUE)
    status = w$process_one()
    result = m$recv(0L)

    expect_true(status)
    expect_equal(result, 1)

    w$close()
    m$close()
})

test_that("worker R API", {
    skip_on_cran()
    skip_on_os("windows")
#    skip_if_not(has_connectivity("localhost")) # -> this or inproc w/ passing context

    m = methods::new(CMQMaster)
    addr = m$listen(sprintf("tcp://127.0.0.1:%i", 6680:6690))

    p = parallel::mcparallel(worker(addr))
    m$recv(1000L)
    m$send(expression(5 + 1), FALSE)
    res = m$cleanup(1000L)
    pc = parallel::mccollect(p)

    expect_equal(res[[1]], 6)
    expect_equal(pc[[1]], NULL)
})
