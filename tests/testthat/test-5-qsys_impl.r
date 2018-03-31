context("qsys implementations")

test_that("qsys_lsf", {
    skip_if_not(all(nchar(Sys.which(c("bsub", "bkill"))) > 0))
    skip_on_os("windows")
    skip_on_cran()
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="lsf", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w)
    expect_equal(r, as.list(1:3*2))
})

test_that("qsys_sge", {
    skip_if_not(all(nchar(Sys.which(c("qsub", "qdel"))) > 0))
    skip_on_os("windows")
    skip_on_cran()
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="sge", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w)
    expect_equal(r, as.list(1:3*2))
})

test_that("qsys_slurm", {
    skip_if_not(all(nchar(Sys.which(c("sbatch", "scancel"))) > 0))
    skip_on_os("windows")
    skip_on_cran()
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="slurm", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w)
    expect_equal(r, as.list(1:3*2))
})

test_that("qsys_pbs", {
    skip_if_not(all(nchar(Sys.which(c("qsub", "qdel"))) > 0))
    skip_on_os("windows")
    skip_on_cran()
    fx = function(x) x*2
    w = workers(n_jobs=1, qsys_id="pbs", reuse=FALSE)
    r = Q(fx, x=1:3, workers=w)
    expect_equal(r, as.list(1:3*2))
})
