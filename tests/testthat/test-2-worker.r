context("worker usage")

test_that("worker evaluation", {
    m = methods::new(CMQMaster)
    w = methods::new(CMQWorker, m$context())
    addr = m$listen("inproc://endpoint")
    w$connect(addr)

    m$recv(-1L)
    m$send(expression(5 * 2), TRUE)
    status = w$process_one()
    result = m$recv(-1L)

    expect_true(status)
    expect_equal(result, 10)

    w$close()
    m$close()
})

test_that("export variable to worker", {
    m = methods::new(CMQMaster)
    w = methods::new(CMQWorker, m$context())
    addr = m$listen("inproc://endpoint")
    w$connect(addr)

    m$add_env("x", 3)
    m$recv(-1L)
    m$send(expression(5 + x), TRUE)
    status = w$process_one()
    result = m$recv(-1L)
    expect_true(status)
    expect_equal(result, 8)

    m$add_env("x", 5)
    m$send(expression(5 + x), TRUE)
    status = w$process_one()
    result = m$recv(-1L)
    expect_true(status)
    expect_equal(result, 10)

    w$close()
    m$close()
})

test_that("load package on worker", {
    m = methods::new(CMQMaster)
    w = methods::new(CMQWorker, m$context())
    addr = m$listen("inproc://endpoint")
    w$connect(addr)

    m$add_pkg("parallel")

    m$recv(-1L)
    m$send(expression(splitIndices(1, 1)[[1]]), TRUE)
    status = w$process_one()
    result = m$recv(-1L)

    expect_true(status)
    expect_equal(result, 1)

    w$close()
    m$close()
})
