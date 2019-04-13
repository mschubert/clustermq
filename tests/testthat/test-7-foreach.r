context("foreach")

foreach = foreach::foreach
`%dopar%` = foreach::`%dopar%`
`%do%` = foreach::`%do%`
register_dopar_cmq(n_jobs=0)

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
    expect_error(foreach(i=1:3, .packages="testthat") %dopar% sqrt(i))
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
    colnames(res) = colnames(cmp) = NULL # ignore names for now
    expect_equal(res, cmp)

    res = foreach(i=1:3, .combine=rbind) %dopar% sqrt(i)
    cmp = foreach(i=1:3, .combine=rbind) %do% sqrt(i)
    rownames(res) = rownames(cmp) = NULL # ignore names for now
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
