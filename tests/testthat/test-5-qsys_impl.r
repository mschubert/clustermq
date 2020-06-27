context("qsys implementations")

has_cmq = has_cmq()
has_network = has_connectivity(Sys.info()["nodename"])
avail = Sys.which(c("bsub", "qsub", "sbatch", "fake_scheduler.sh"))
avail = as.list(nchar(avail) != 0)
fx = function(x) x*2

test_that("local, explicit", {
    w = workers(n_jobs=4, qsys_id="local")
    r = Q(fx, x=1:3, workers=w, timeout=3L)
    success = w$cleanup()
    expect_equal(r, as.list(1:3*2))
    expect_equal(success, TRUE)
})

test_that("local, n_jobs=0", {
    fx = function(x) x*2
    r = Q(fx, x=1:3, n_jobs=0, timeout=3L)
    expect_equal(r, as.list(1:3*2))
})

test_that("qsys_multicore", {
    skip_on_os("windows")
    w = workers(n_jobs=4, qsys_id="multicore", reuse=TRUE)
    r = Q(fx, x=1:3, workers=w, timeout=3L)
    success = w$cleanup()
    expect_equal(r, as.list(1:3*2))
    expect_equal(success, TRUE)
})

# can not combine with multicore tests: https://github.com/r-lib/processx/issues/236
#test_that("qsys_multiprocess (callr)", {
#    w = workers(n_jobs=2, qsys_id="multiprocess", reuse=TRUE)
#    r = Q(fx, x=1:3, workers=w, timeout=3L)
#    success = w$cleanup()
#    expect_equal(r, as.list(1:3*2))
#    expect_equal(success, TRUE)
#})

test_that("qsys_lsf", {
    skip_on_cran()
    skip_if_not(with(avail, bsub))
    skip_if_not(has_cmq)
    skip_if_not(has_network)
    skip_on_os("windows")
    w = workers(n_jobs=1, qsys_id="lsf", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w, timeout=3L)
    expect_equal(r, as.list(1:3*2))
})

test_that("qsys_sge", {
    skip_on_cran()
    skip_if_not(with(avail, qsub))
    skip_if_not(has_cmq)
    skip_if_not(has_network)
    skip_on_os("windows")
    w = workers(n_jobs=1, qsys_id="sge", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w, timeout=3L)
    expect_equal(r, as.list(1:3*2))
})

test_that("qsys_slurm", {
    skip_on_cran()
    skip_if_not(with(avail, sbatch))
    skip_if_not(has_cmq)
    skip_if_not(has_network)
    skip_on_os("windows")
    w = workers(n_jobs=1, qsys_id="slurm", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w, timeout=3L)
    expect_equal(r, as.list(1:3*2))
})
