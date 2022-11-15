context("worker usage")

test_that("timeouts are triggered correctly", {
    m = methods::new(CMQMaster)
    addr = m$listen("inproc://endpoint")
    expect_error(m$recv(0L))
    m$close()
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
