context("qsys")

w = create_worker_pool(1, qsys_id="multicore")

test_that("control flow", {
    fx = function(x) x*2
    result = Q(fx, x=1:3, workers=w)
    expect_equal(result, as.list(1:3*2))
})

test_that("common data", {
    fx = function(x, y) x*2 + y
    result = Q(fx, x=1:3, const=list(y=10), workers=w)
    expect_equal(result, as.list(1:3*2+10))
})

test_that("export", {
    fx = function(x) x*2 + z
    result = Q(fx, x=1:3, export=list(z=20), workers=w)
    expect_equal(result, as.list(1:3*2+20))
})

test_that("seed reproducibility", {
    fx = function(x) sample(1:100, 1)
    r1 = Q(fx, x=1:3, workers=w)
    r2 = Q(fx, x=1:3, workers=w)
    expect_equal(r1, r2)
})
