context("proxy")

has_localhost = has_connectivity("127.0.0.1")

test_that("control flow between proxy and master", {
    skip_if_not(has_localhost)
    skip_on_os("windows")

    zmq = ZeroMQ$new()
    port_ctl = as.integer(sub(".*:", "", zmq$listen())) #todo: sure this is always integer?
    port_job = as.integer(sub(".*:", "", zmq$listen(sid="job")))
    common_data = list(id="DO_SETUP", fun = function(x) x*2,
            const=list(), export=list(), seed=1)
    p = parallel::mcparallel(ssh_proxy(port_ctl, port_job, 'multicore'))
    on.exit(tools::pskill(p$pid, tools::SIGKILL))

    # startup
    msg = zmq$receive()
    expect_equal(msg$id, "PROXY_UP")
    worker_url = msg$worker_url

    zmq$send(common_data)
    msg = zmq$receive()
    expect_equal(msg$id, "PROXY_READY")
    expect_true("data_url" %in% names(msg))
    expect_true("token" %in% names(msg))
#    token = msg$token

    # command execution
    cmd = quote(Sys.getpid())
    zmq$send(list(id="PROXY_CMD", exec=cmd))
    msg = zmq$receive()
    expect_equal(msg$id, "PROXY_CMD")
    expect_equal(msg$reply, p$pid)

    # start up worker
    zmq$connect(worker_url, sid="worker")
    zmq$send(list(id="WORKER_READY"), sid="worker")
    msg = zmq$receive(sid="job")
    testthat::expect_equal(msg$id, "WORKER_READY")

    # shutdown
    zmq$send(list(id = "PROXY_STOP"))
    collect = suppressWarnings(parallel::mccollect(p))
    expect_equal(as.integer(names(collect)), p$pid)
    on.exit(NULL)
})

test_that("full SSH connection", {
    skip_on_cran()
    skip_on_os("windows")
    skip_if_not(has_localhost)
    skip_if_not(has_ssh_cmq("127.0.0.1"))

    # 'LOCAL' mode (default) will not set up required sockets
    # 'SSH' mode would lead to circular connections
    # schedulers may have long delay (they start in fresh session, so no path)
    sched = getOption("clustermq.scheduler", qsys_default)
    skip_if(is.null(sched) || toupper(sched) != "MULTICORE",
            message="options(clustermq.scheduler') must be 'MULTICORE'")

    options(clustermq.template = "SSH")
    w = workers(n_jobs=1, qsys_id="ssh", reuse=FALSE,
                ssh_host="127.0.0.1", addr="tcp://127.0.0.1:*")
    result = Q(identity, 42, n_jobs=1, timeout=10L, workers=w)
    expect_equal(result, list(42))
})
