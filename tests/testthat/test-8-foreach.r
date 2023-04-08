context("foreach")

foreach = foreach::foreach
`%dopar%` = foreach::`%dopar%`
`%do%` = foreach::`%do%`
register_dopar_cmq(n_jobs=0)

test_that("foreach::getDoParWorkers() returns n_jobs", {
    expect_equal(foreach::getDoParWorkers(), 0)
})

test_that("simple foreach registration works", {
    res = foreach(i=1:3) %dopar% sqrt(i)
    cmp = foreach(i=1:3) %do% sqrt(i)

    expect_equal(res, cmp)
})

test_that(".export objects are exported", {
    y = 5
    res = foreach(x=1:3, .export="y") %dopar% { x + y }
    cmp = foreach(x=1:3, .export="y") %do% { x + y }

    expect_equal(res, cmp)
#    expect_error(foreach(x=1:3) %dopar% { x + y })
})

test_that(".packages are loaded", {
    expect_error(foreach(i="a string") %dopar% { md5sum(i) })
    res = foreach(i="a string", .packages="tools") %dopar% { md5sum(i) }
    cmp = foreach(i="a string") %do% { md5sum(i) }
    expect_equal(res, cmp)
})

test_that(".combine is respected", {
    res = foreach(i=1:3, .combine=c) %dopar% sqrt(i)
    cmp = foreach(i=1:3, .combine=c) %do% sqrt(i)
    expect_equal(res, cmp)

    res = foreach(i=1:3, .combine=append) %dopar% list(a=1, b=2)
    cmp = foreach(i=1:3, .combine=append) %do% list(a=1, b=2)
    expect_equal(res, cmp)

    res = foreach(i=1:3, .combine=cbind) %dopar% sqrt(i)
    cmp = foreach(i=1:3, .combine=cbind) %do% sqrt(i)
    expect_equal(res, cmp)

    res = foreach(i=1:3, .combine=rbind) %dopar% sqrt(i)
    cmp = foreach(i=1:3, .combine=rbind) %do% sqrt(i)
    expect_equal(res, cmp)
})

test_that("no matrix unlisting (#143)", {
    fx = function(x) matrix(c(1,2)+x, ncol=1)
    res = foreach(i=1:3) %dopar% fx(i)
    cmp = foreach(i=1:3) %do% fx(i)
    expect_equal(res, cmp)
})

test_that("automatic export in foreach", {
    fx = function(x) x + y
    y = 5
    res = foreach(x=1:3) %dopar% { x + y }
    cmp = foreach(x=1:3) %do% { x + y }
    expect_equal(res, cmp)
})

test_that("NULL objects are exported", {
    fx = function(x) is.null(x)
    y = NULL
    res = foreach(i=1) %dopar% fx(y)
    cmp = foreach(i=1) %do% fx(y)
    expect_equal(res, cmp)
})

test_that("external worker", {
    register_dopar_cmq(n_jobs=1)
    res = foreach(i=1:3) %dopar% sqrt(i)
    cmp = foreach(i=1:3) %do% sqrt(i)
    expect_equal(res, cmp)
})

#test_that("foreach works via BiocParallel", {
#    skip_if_not_installed("BiocParallel")
#
#    BiocParallel::register(BiocParallel::DoparParam())
#    res = BiocParallel::bplapply(1:3, sqrt)
#    cmp = foreach(i=1:3) %do% sqrt(i)
#
#    expect_equal(res, cmp)
#})
