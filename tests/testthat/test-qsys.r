context("qsys")
skip_on_os("windows")

test_that("control flow", {
    fx = function(x) x*2
    r = Q(fx, x=1:3, workers=workers(n_jobs=1, qsys_id="multicore", reuse=FALSE))
    expect_equal(r, as.list(1:3*2))
})

test_that("common data", {
    fx = function(x, y) x*2 + y
    r = Q(fx, x=1:3, const=list(y=10),
          workers = workers(n_jobs=1, qsys_id="multicore", reuse=FALSE))
    expect_equal(r, as.list(1:3*2+10))
})

test_that("export", {
    fx = function(x) x*2 + z
    r = Q(fx, x=1:3, export=list(z=20),
          workers = workers(n_jobs=1, qsys_id="multicore", reuse=FALSE))
    expect_equal(r, as.list(1:3*2+20))
})

test_that("seed reproducibility", {
    fx = function(x) sample(1:100, 1)
    r1 = Q(fx, x=1:3, workers=workers(n_jobs=1, qsys_id="multicore", reuse=FALSE))
    r2 = Q(fx, x=1:3, workers=workers(n_jobs=1, qsys_id="multicore", reuse=FALSE))
    expect_equal(r1, r2)
})

test_that("master does not exit loop prematurely", {
    fx = function(x) {
        Sys.sleep(0.5)
        x*2
    }
    r = Q(fx, x=1:3, workers=workers(n_jobs=2, qsys_id="multicore", reuse=FALSE))
    expect_equal(r, as.list(1:3*2))
})