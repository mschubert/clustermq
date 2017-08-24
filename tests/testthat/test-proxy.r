context("proxy")

test_that("control flow", {
    skip_on_os("windows")

    # prerequesites
    context = rzmq::init.context()
    socket = rzmq::init.socket(context, "ZMQ_REP")
    port = bind_avail(socket, 50000:55000)
    Sys.sleep(0.5)
    common_data = list(fun = function(x) x*2, const=list(), export=list(), seed=1)
    master = sprintf("tcp://localhost:%i", port)
    p = parallel::mcparallel(proxy(master))

    # startup
    msg = rzmq::receive.socket(socket)
    expect_equal(msg$id, "PROXY_UP")

    rzmq::send.socket(socket, common_data)
    msg = rzmq::receive.socket(socket)
    expect_equal(msg$id, "PROXY_READY")
    expect_true("data_url" %in% names(msg))
    proxy = msg$data_url

    # command execution
    cmd = methods::Quote(Sys.getpid())
    rzmq::send.socket(socket, list(id="PROXY_CMD", exec=cmd))
    msg = rzmq::receive.socket(socket)
    expect_equal(msg$id, "PROXY_CMD")
    expect_equal(msg$reply, p$pid)

    # common data
    worker = rzmq::init.socket(context, "ZMQ_REQ")
    rzmq::connect.socket(worker, proxy)

    rzmq::send.socket(worker, list(id="WORKER_UP"))
    msg = rzmq::receive.socket(worker)
    testthat::expect_equal(msg, common_data)

    # port forwarding
    # ???

    # shutdown
    msg = list(id = "PROXY_STOP")
    rzmq::send.socket(socket, msg)
    Sys.sleep(0.5)

    collect = parallel::mccollect(p)
    expect_equal(as.integer(names(collect)), p$pid)
})
