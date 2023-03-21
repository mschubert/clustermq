context("ssh proxy")

test_that("simple forwarding works", {
    m = methods::new(CMQMaster)
    p = methods::new(CMQProxy, m$context())
    w = methods::new(CMQWorker, m$context())
    addr1 = m$listen("inproc://master")
    addr2 = p$listen("inproc://proxy")
    p$connect(addr1, 0L)
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

test_that("proxy communication yields submit args", {
    m = methods::new(CMQMaster)
    p = methods::new(CMQProxy, m$context())
    addr1 = m$listen("inproc://master")
    addr2 = p$listen("inproc://proxy")

    # direct connection, no ssh forward here
    p$connect(addr1, 0L)
    p$proxy_request_cmd()
    m$proxy_submit_cmd(list(n_jobs=1), 0L)
    args = p$proxy_receive_cmd()

    expect_true(inherits(args, "list"))
    expect_true("n_jobs" %in% names(args))

    p$close(0L)
    m$close(0L)
})

test_that("starting the proxy without forward", {
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

    m = methods::new(CMQMaster)
    addr = m$listen("tcp://127.0.0.1:*")
    p = parallel::mcparallel(SSH$new(addr, 1, ssh_host="127.0.0.1", ssh_log="~/cmq_ssh.log"))

    m$proxy_submit_cmd(list(n_jobs=1), 5000L)
    wrk_up = m$recv(1000L)
    m$send(expression(5 + 2), FALSE)
#    m$recv(1000L) # crash

    parallel::mccollect(p)
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

    options(clustermq.template = "SSH", clustermq.ssh.host="127.0.0.1")
    w = workers(n_jobs=1, qsys_id="ssh", reuse=FALSE)
    result = Q(identity, 42, n_jobs=1, timeout=10L, workers=w)
    expect_equal(result, list(42))
})
