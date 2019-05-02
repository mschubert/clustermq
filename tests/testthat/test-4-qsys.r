context("qsys")

has_localhost = has_connectivity("localhost")

test_that("control flow", {
    skip_if_not(has_localhost)
    skip_on_os("windows")
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="multicore", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w, timeout=3L)
    expect_equal(r, as.list(1:3*2))
})

test_that("control flow with automatic workers", {
    skip_if_not(has_localhost)
    skip_on_os("windows")
    fx = function(x) x*2
    options(clustermq.scheduler = "multicore")
    r = Q(fx, x=1:3, n_jobs=1, timeout=3L)
    expect_equal(r, as.list(1:3*2))
})

test_that("common data", {
    skip_if_not(has_localhost)
    skip_on_os("windows")
    fx = function(x, y) x*2 + y
    w = workers(n_jobs=1, qsys_id="multicore", reuse=FALSE)
    r = Q(fx, x=1:3, const=list(y=10), workers=w, timeout=3L)
    expect_equal(r, as.list(1:3*2+10))
})

test_that("export", {
    skip_if_not(has_localhost)
    skip_on_os("windows")
    fx = function(x) x*2 + z
    w = workers(n_jobs=1, qsys_id="multicore", reuse=FALSE)
    r = Q(fx, x=1:3, export=list(z=20), workers=w, timeout=3L)
    expect_equal(r, as.list(1:3*2+20))
})

test_that("load package on worker", {
    skip_if_not(has_localhost)
    skip_on_os("windows")
    fx = function(x) md5sum(x)
    x = "a string"
    w = workers(n_jobs=1, qsys_id="multicore", reuse=FALSE)
    r = Q(fx, x=x, pkgs=c("tools"), workers=w, rettype="character", timeout=3L)
    expect_equal(r, unname(tools::md5sum(x)))
})

test_that("seed reproducibility", {
    skip_if_not(has_localhost)
    skip_on_os("windows")
    fx = function(x) sample(1:100, 1)
    w1 = workers(n_jobs=1, qsys_id="multicore", reuse=FALSE)
    w2 = workers(n_jobs=1, qsys_id="multicore", reuse=FALSE)
    r1 = Q(fx, x=1:3, workers=w1, timeout=3L)
    r2 = Q(fx, x=1:3, workers=w2, timeout=3L)
    expect_equal(r1, r2)
})

test_that("master does not exit loop prematurely", {
    skip_if_not(has_localhost)
    skip_on_os("windows")
    fx = function(x) {
        Sys.sleep(0.5)
        x*2
    }
    w = workers(n_jobs=2, qsys_id="multicore", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w, timeout=3L)
    expect_equal(r, as.list(1:3*2))
})

test_that("rettype is respected", {
    skip_if_not(has_localhost)
    skip_on_os("windows")
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="multicore", reuse=FALSE)
    r = Q(fx, x=1:3, rettype="numeric", workers=w, timeout=3L)
    expect_equal(r, 1:3*2)
})

test_that("worker timeout throws error", {
    skip_if_not(has_localhost)
    skip_on_os("windows")
    w = workers(n_jobs=1, qsys_id="multicore", reuse=FALSE)
    expect_error(expect_warning(
        Q(Sys.sleep, 3, rettype="numeric", workers=w, timeout=1L)))
})

test_that("error timeout works", {
    skip_if_not(has_localhost)
    skip_on_os("windows")
    fx = function(x) {
        Sys.sleep(x)
        stop("error")
    }

    options(clustermq.error.timeout = 3)
    w = workers(n_jobs=2, qsys_id="multicore", reuse=FALSE)

    times = system.time({
        expect_error(expect_warning(Q(fx, x=c(1,10), workers=w, timeout=10)))
    })
    expect_true(times[["elapsed"]] < 5)
})

test_that("Q with expired workers throws error quickly", {
    skip_if_not(has_localhost)
    skip_on_os("windows")

    w = workers(n_jobs=1, qsys_id="multicore", reuse=FALSE)
    w$cleanup()

    times = system.time({
        expect_error(Q(identity, x=1:3, rettype="numeric", workers=w, timeout=3L))
    })
    expect_true(times[["elapsed"]] < 1)
})
