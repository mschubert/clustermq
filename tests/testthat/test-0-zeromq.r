context("zeromq")

test_that("fail on binding invalid endpoint", {
    server = ZeroMQ$new()
    expect_error(server$listen(iface="tcp://"))
})

test_that("send data on a round trip", {
    server = ZeroMQ$new()
    port = server$listen()

    client = ZeroMQ$new()
    client$connect(paste0("tcp://localhost:", port))

    client$send("test")
    rcv = server$receive()
    expect_equal(rcv, "test")
})

test_that("send/receive more", {
    server = ZeroMQ$new()
    port = server$listen()

    client = ZeroMQ$new()
    client$connect(paste0("tcp://localhost:", port))

    client$send("test", send_more=TRUE)
    client$send("test2")
    rcv  = server$receive()
    rcv2  = server$receive()
    expect_equal(c(rcv, rcv2), c("test", "test2"))
})

test_that("multiple sockets", {
    zmq = ZeroMQ$new()
    zmq$listen2("inproc://endpoint", sid="server")
    zmq$connect("inproc://endpoint", sid="client")
    zmq$send("test3", sid="client")
    rcv = zmq$receive(sid="server")
    expect_equal(rcv, "test3")
})

test_that("multiple sockets, explicit disconnect", {
    zmq = ZeroMQ$new()
    zmq$listen2("inproc://endpoint", sid="server")
    zmq$connect("inproc://endpoint", sid="client")
    zmq$send("test4", sid="client")
    zmq$disconnect(sid="client")
    rcv = zmq$receive(sid="server")
    expect_equal(rcv, "test4")
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
