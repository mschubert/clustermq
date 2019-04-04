context("foreach")

foreach = foreach::foreach
`%dopar%` = foreach::`%dopar%`
`%do%` = foreach::`%do%`

test_that("simple foreach registration works", {
    register_dopar_cmq(n_jobs=0)

    res = foreach(i=1:3) %dopar% sqrt(i)
    cmp = foreach(i=1:3) %do% sqrt(i)

    expect_equal(res, cmp)
})

test_that(".export objects are exported", {
    register_dopar_cmq(n_jobs=0)
    y = 5

    res = foreach(x=1:3, .export="y") %dopar% { x + y }
    cmp = foreach(x=1:3, .export="y") %do% { x + y }

    expect_equal(res, cmp)
#    expect_error(foreach(x=1:3) %dopar% { x + y })
})

test_that(".packages are loaded", {
    register_dopar_cmq(n_jobs=0)

    expect_error(foreach(i=1:3, .packages="testthat") %dopar% sqrt(i))
})
