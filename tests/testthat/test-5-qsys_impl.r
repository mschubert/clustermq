context("qsys implementations")

avail = nchar(Sys.which(c("bsub", "qsub", "qsh", "sbatch", "fake_scheduler.sh"))) != 0

test_that("qsys_lsf", {
    # skip_if[_not] seems to be implemented the wrong way?
    if (!avail['bsub']) skip("bsub not found")
    skip_on_os("windows")
    skip_on_cran()
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="lsf", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w)
    expect_equal(r, as.list(1:3*2))
})

test_that("qsys_sge", {
    if (!avail['qsub'] || (!avail['qsh'] && !avail['fake_scheduler.sh']))
        skip("SGE qsub not found")
    skip_on_os("windows")
    skip_on_cran()
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="sge", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w)
    expect_equal(r, as.list(1:3*2))
})

test_that("qsys_slurm", {
    if (!avail['sbatch']) skip("sbatch not found")
    skip_on_os("windows")
    skip_on_cran()
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="slurm", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w)
    expect_equal(r, as.list(1:3*2))
})

test_that("qsys_pbs", {
    if (!avail['qsub'] || (avail['qsh'] && !avail['fake_scheduler.sh']))
        skip("PBS qsub not found")
    skip_on_os("windows")
    skip_on_cran()
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="pbs", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w)
    expect_equal(r, as.list(1:3*2))
})
