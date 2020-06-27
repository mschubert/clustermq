context("bindings")

test_that("send data on a round trip", {
    ctx = init_context()
    srv = init_socket(ctx, "ZMQ_REP")
    bind_socket(srv, "inproc://endpoint")

    cl = init_socket(ctx, "ZMQ_REQ")
    connect_socket(cl, "inproc://endpoint")

    send_socket(cl, "test")
    rcv = receive_socket(srv)
    expect_equal(rcv, "test")
})

test_that("send/receive more", {
    ctx = init_context()
    srv = init_socket(ctx, "ZMQ_REP")
    bind_socket(srv, "inproc://endpoint")

    cl = init_socket(ctx, "ZMQ_REQ")
    connect_socket(cl, "inproc://endpoint")

    send_socket(cl, "test", send_more=TRUE)
    send_socket(cl, "test2")
    rcv = receive_multipart(srv)
    expect_equal(rcv, list("test", "test2"))
})
