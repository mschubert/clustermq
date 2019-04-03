context("proxy")

has_localhost = has_connectivity("localhost")

test_that("control flow between proxy and master", {
    skip_if_not(has_localhost)
    skip_on_os("windows")

    # prerequesites
    context = rzmq::init.context()
    socket = rzmq::init.socket(context, "ZMQ_REP")
    port = bind_avail(socket, 50000:55000)
    common_data = list(id="DO_SETUP", fun = function(x) x*2,
            const=list(), export=list(), seed=1)
    p = parallel::mcparallel(ssh_proxy(port, port, 'multicore'))
    on.exit(tools::pskill(p$pid, tools::SIGKILL))

    # startup
    msg = recv(p, socket)
    expect_equal(msg$id, "PROXY_UP")

    send(socket, common_data)
    msg = recv(p, socket)
    expect_equal(msg$id, "PROXY_READY")
    expect_true("data_url" %in% names(msg))
    expect_true("token" %in% names(msg))
    proxy = msg$data_url
    token = msg$token

    # command execution
    cmd = quote(Sys.getpid())
    send(socket, list(id="PROXY_CMD", exec=cmd))
    msg = recv(p, socket)
    expect_equal(msg$id, "PROXY_CMD")
    expect_equal(msg$reply, p$pid)

    # common data
    worker = rzmq::init.socket(context, "ZMQ_REQ")
    rzmq::connect.socket(worker, proxy)

    send(worker, list(id="WORKER_READY"))
    msg = recv(p, worker)
    testthat::expect_equal(msg$id, "DO_SETUP")
    testthat::expect_equal(msg$token, token)
    testthat::expect_equal(msg[names(common_data)], common_data)

    # shutdown
    msg = list(id = "PROXY_STOP")
    send(socket, msg)
    collect = suppressWarnings(parallel::mccollect(p))
    expect_equal(as.integer(names(collect)), p$pid)
    on.exit(NULL)
})

test_that("full SSH connection", {
    skip_on_cran()
    skip_on_os("windows")
    skip_if_not(has_localhost)
    skip_if_not(has_ssh_cmq("localhost"))

    # 'LOCAL' mode (default) will not set up required sockets
    sched = getOption("clustermq.scheduler", qsys_default)
    skip_if(is.null(sched) || toupper(sched) == "LOCAL",
            message="options(clustermq.scheduler') can not be 'LOCAL'")

    w = workers(n_jobs=1, qsys_id="ssh", reuse=FALSE,
                ssh_host="localhost", node="localhost")
    result = Q(identity, 42, n_jobs=1, timeout=10L, workers=w)
    expect_equal(result, list(42))
})
