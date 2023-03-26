context("ssh proxy")

has_localhost = has_connectivity("127.0.0.1")

# in the following 2 tests, passing the context is deactivated because running
# the first test twice leads to a segfault; not sure why, fix this eventually
test_that("simple forwarding works", {
    skip_if_not(has_localhost)

    m = methods::new(CMQMaster)
    p = methods::new(CMQProxy)#, m$context())
    w = methods::new(CMQWorker)#, m$context())
    addr1 = m$listen("tcp://127.0.0.1:*")#"inproc://master")
    addr2 = p$listen("tcp://127.0.0.1:*")#"inproc://proxy")
    p$connect(addr1, 0L)
    w$connect(addr2, 0L)
    expect_true(p$process_one())
    expect_null(m$recv(0L)) # worker up
    m$send(expression(5 + 2), TRUE)
    expect_true(p$process_one())
    expect_true(w$process_one())
    expect_true(p$process_one())
    result = m$recv(0L)
    expect_equal(result, 7)

    w$close()
    p$close(0L)
    m$close(0L)
})

test_that("proxy communication yields submit args", {
    skip_if_not(has_localhost)

    m = methods::new(CMQMaster)
    p = methods::new(CMQProxy)#, m$context())
    addr1 = m$listen("tcp://127.0.0.1:*")#"inproc://master")
    addr2 = p$listen("tcp://127.0.0.1:*")#"inproc://proxy")

    # direct connection, no ssh forward here
    p$connect(addr1, 0L)
    p$proxy_request_cmd()
    m$proxy_submit_cmd(list(n_jobs=1), 1000L)
    args = p$proxy_receive_cmd()

    expect_true(inherits(args, "list"))
    expect_true("n_jobs" %in% names(args))

    p$close(0L)
    m$close(0L)
})

test_that("using the proxy without pool and forward", {
    skip("using 1 worker: Error: Resource temporarily unavailable @m$recv (L63)")
    skip_on_cran()
    skip_on_os("windows")
    skip_if_not(has_localhost)

    m = methods::new(CMQMaster)
    addr = m$listen("tcp://127.0.0.1:*")
    p = parallel::mcparallel(ssh_proxy(sub(".*:", "", addr)))

    m$proxy_submit_cmd(list(n_jobs=1), 5000L)
    expect_null(m$recv(1000L)) # worker 1 up
    m$send(expression({ Sys.sleep(0.5); 5 + 2 }), FALSE)
    res = m$cleanup(1000L) # collect results
    expect_equal(res, list(7))

    pr = parallel::mccollect(p, wait=TRUE, timeout=0.5)
    expect_equal(names(pr), as.character(p$pid))
})

test_that("using the proxy without pool and forward, 2 workers", {
    skip("using 2 workers: Assertion failed: check () (src/msg.cpp:414) on CI")
    skip_on_cran()
    skip_on_os("windows")
    skip_if_not(has_localhost)

    m = methods::new(CMQMaster)
    addr = m$listen("tcp://127.0.0.1:*")
    p = parallel::mcparallel(ssh_proxy(sub(".*:", "", addr)))

    m$proxy_submit_cmd(list(n_jobs=2), 5000L)
    expect_null(m$recv(1000L)) # worker 1 up
    m$send(expression({ Sys.sleep(0.5); 5 + 2 }), FALSE)
    expect_null(m$recv(1000L)) # worker 2 up
    m$send(expression({ Sys.sleep(0.5); 3 + 1 }), FALSE)
    res = m$cleanup(1000L) # collect both results
    expect_equal(res, list(7, 4))

    pr = parallel::mccollect(p, wait=TRUE, timeout=0.5)
    expect_equal(names(pr), as.character(p$pid))
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
    w = workers(n_jobs=1, qsys_id="ssh", reuse=FALSE, log_worker=T)
    result = Q(identity, 42, n_jobs=1, timeout=10L, workers=w)
    expect_equal(result, list(42))
})
