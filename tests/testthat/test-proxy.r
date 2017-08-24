context("proxy")

test_that("control flow between proxy and master", {
    skip_on_os("windows")

    recv = function(sock, timeout=3L) {
        event = rzmq::poll.socket(list(sock), list("read"), timeout=timeout)
        if (event[[1]]$read)
            rzmq::receive.socket(sock)
        else
            warning(parallel::mccollect(p)[[1]], immediate.=TRUE)
    }

    # prerequesites
    context = rzmq::init.context()
    socket = rzmq::init.socket(context, "ZMQ_REP")
    port = bind_avail(socket, 50000:55000)
    Sys.sleep(0.5)
    common_data = list(fun = function(x) x*2, const=list(), export=list(), seed=1)
    p = parallel::mcparallel(proxy(port, port))

    # startup
    msg = recv(socket)
    expect_equal(msg$id, "PROXY_UP")

    rzmq::send.socket(socket, common_data)
    msg = recv(socket)
    expect_equal(msg$id, "PROXY_READY")
    expect_true("data_url" %in% names(msg))
    proxy = msg$data_url

    # command execution
    cmd = methods::Quote(Sys.getpid())
    rzmq::send.socket(socket, list(id="PROXY_CMD", exec=cmd))
    msg = recv(socket)
    expect_equal(msg$id, "PROXY_CMD")
    expect_equal(msg$reply, p$pid)

    # common data
    worker = rzmq::init.socket(context, "ZMQ_REQ")
    rzmq::connect.socket(worker, proxy)

    rzmq::send.socket(worker, list(id="WORKER_UP"))
    msg = recv(worker)
    testthat::expect_equal(msg, common_data)

    # shutdown
    msg = list(id = "PROXY_STOP")
    rzmq::send.socket(socket, msg)
    Sys.sleep(0.5)

    collect = parallel::mccollect(p)
    expect_equal(as.integer(names(collect)), p$pid)
})
