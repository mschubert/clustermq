context("qsys implementations")

has_network = has_connectivity(Sys.info()[['nodename']])
avail = Sys.which(c("bsub", "qsub", "qsh", "sbatch", "fake_scheduler.sh"))
avail = as.list(nchar(avail) != 0)

test_that("qsys_lsf", {
    skip_if_not_installed('clustermq')
    skip_if_not(with(avail, bsub))
    skip_if_not(has_network)
    skip_on_os("windows")
    skip_on_cran()
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="lsf", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w, timeout=3L)
    expect_equal(r, as.list(1:3*2))
})

test_that("qsys_sge", {
    skip_if_not_installed('clustermq')
    skip_if_not(with(avail, qsub && (qsh || fake_scheduler.sh)))
    skip_if_not(has_network)
    skip_on_os("windows")
    skip_on_cran()
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="sge", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w, timeout=3L)
    expect_equal(r, as.list(1:3*2))
})

test_that("qsys_slurm", {
    skip_if_not_installed('clustermq')
    skip_if_not(with(avail, sbatch))
    skip_if_not(has_network)
    skip_on_os("windows")
    skip_on_cran()
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="slurm", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w, timeout=3L)
    expect_equal(r, as.list(1:3*2))
})

test_that("qsys_pbs", {
    skip_if_not_installed('clustermq')
    skip_if(with(avail, !qsub || (qsh && !fake_scheduler.sh)))
    skip_if_not(has_network)
    skip_on_os("windows")
    skip_on_cran()
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="pbs", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w, timeout=3L)
    expect_equal(r, as.list(1:3*2))
})
