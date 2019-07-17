context("bindings")

test_that("send data on a round trip", {
    ctx = initContext(1L)
    srv = initSocket(ctx, "ZMQ_REP")
    bindSocket(srv, "inproc://endpoint")

    cl = initSocket(ctx, "ZMQ_REQ")
    connectSocket(cl, "inproc://endpoint")

    sendSocket(cl, "test")
    rcv = receiveSocket(srv)
    expect_equal(rcv, "test")
})
