context("ssh proxy")

test_that("simple forwarding works", {
    m = methods::new(CMQMaster)
    p = methods::new(CMQProxy, m$context())
    w = methods::new(CMQWorker, m$context())
    addr1 = m$listen("inproc://master")
    p$connect(addr1, 0L)
    addr2 = p$listen("inproc://proxy")
    w$connect(addr2, 0L)

    p$process_one()
    m$recv(0L)
    m$send(expression(5 + 2), TRUE)
    p$process_one()
    status = w$process_one()
    p$process_one()
    result = m$recv(0L)

    expect_true(status)
    expect_equal(result, 7)

    w$close()
    p$close(0L)
    m$close(0L)
})

#test_that("", {
#})
