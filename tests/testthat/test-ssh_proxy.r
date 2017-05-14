context("ssh_proxy")

context = rzmq::init.context()
socket = rzmq::init.socket(context, "ZMQ_REP")
port = bind_avail(socket, 50000:55000)
Sys.sleep(0.5)
if (Sys.info()[['sysname']] == "Windows")
    skip("Forking not available on Windows")
p = parallel::mcparallel(ssh_proxy(port))

common_data = list(fun = function(x) x*2, const=list(), seed=1)

test_that("control flow", {
    # startup
    msg = rzmq::receive.socket(socket)
    expect_equal(msg$id, "SSH_UP")

    rzmq::send.socket(socket, common_data)
    msg = rzmq::receive.socket(socket)
    expect_equal(msg$id, "SSH_READY")
    expect_true("proxy" %in% names(msg))
    proxy = msg$proxy

    # heartbeating
    rzmq::send.socket(socket, list(id="SSH_NOOP"))
    msg = rzmq::receive.socket(socket)
    expect_equal(msg$id, "SSH_NOOP")

    # command execution
    cmd = methods::Quote(Sys.getpid())
    rzmq::send.socket(socket, list(id="SSH_CMD", exec=cmd))
    msg = rzmq::receive.socket(socket)
    expect_equal(msg$id, "SSH_CMD")
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
    msg = list(id = "SSH_STOP")
    rzmq::send.socket(socket, msg)
    Sys.sleep(0.5)

    collect = parallel::mccollect(p)
    expect_equal(as.integer(names(collect)), p$pid)
})
