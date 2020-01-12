context("bindings")

test_that("send data on a round trip", {
    server = ZeroMQ$new()
    server$listen("tcp://*:56123")

    client = ZeroMQ$new()
    client$connect("tcp://localhost:56123")

    client$send("test")
    rcv = server$receive()
    expect_equal(rcv, "test")
})

test_that("send/receive more", {
    server = ZeroMQ$new()
    server$listen("tcp://*:56124")

    client = ZeroMQ$new()
    client$connect("tcp://localhost:56124")

    client$send("test", send_more=TRUE)
    client$send("test2")
    rcv  = server$receive()
    rcv2  = server$receive()
    expect_equal(c(rcv, rcv2), c("test", "test2"))
})

#test_that("overwriting object does not lock state", {
#    server = ZeroMQ$new()
#    server$listen("tcp://*:56125")
#    server = ZeroMQ$new()
#    gc()
#    rm(server)
#    gc()
#    expect_true(TRUE)
#})
