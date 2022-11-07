context("worker usage")

test_that("worker evaluation", {
    ctx = zmq_context()
    m = methods::new(CMQMaster, ctx)
    w = methods::new(CMQWorker, ctx)
    addr = m$listen("inproc://endpoint")
    w$connect(addr)

    m$recv(-1L)
    m$send(expression(5 * 2))
    status = w$process_one()
    result = m$recv(-1L)

    expect_true(status)
    expect_equal(result, 10)

    w$close()
    m$close()
    ctx_close(ctx)
})

test_that("export variable to worker", {
    ctx = zmq_context()
    m = methods::new(CMQMaster, ctx)
    w = methods::new(CMQWorker, ctx)
    addr = m$listen("inproc://endpoint")
    w$connect(addr)

    m$add_env("x", 3)
    m$recv(-1L)
    m$send(expression(5 + x))
    status = w$process_one()
    result = m$recv(-1L)
    expect_true(status)
    expect_equal(result, 8)

    m$add_env("x", 5)
    m$send(expression(5 + x))
    status = w$process_one()
    result = m$recv(-1L)
    expect_true(status)
    expect_equal(result, 10)

    w$close()
    m$close()
    ctx_close(ctx)
})

test_that("load package on worker", {
    ctx = zmq_context()
    m = methods::new(CMQMaster, ctx)
    w = methods::new(CMQWorker, ctx)
    addr = m$listen("inproc://endpoint")
    w$connect(addr)

    m$add_pkg("parallel")

    m$recv(-1L)
    m$send(expression(splitIndices(1, 1)[[1]]))
    status = w$process_one()
    result = m$recv(-1L)

    expect_true(status)
    expect_equal(result, 1)

    w$close()
    m$close()
    ctx_close(ctx)
})
