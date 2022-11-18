context("pool")

test_that("starting and stopping multicore", {
    w = workers(1, qsys_id="multicore")
    expect_null(w$recv())
    w$send(expression(3 + 4))
    expect_equal(w$recv(), 7)
    w$send_shutdown()
    w$cleanup()
})
