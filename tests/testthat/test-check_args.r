context("check_args")

test_that("required args are provided", {
    f1 = function(x) x
    # x is provided
    expect_is(check_args(f1, iter=list(x=1)), "data.frame")
    expect_error(check_args(f1, iter=list(y=1)))

    # don't allow empty iter argument
    expect_error(check_args(f1, iter=list()))
    expect_error(check_args(f1, const=list(x=1)))
})

test_that("no superfluous args unless function takes `...`", {
    f1 = function(x) x
    expect_error(check_args(f1, iter=list(x=1, y=1)))
    expect_error(check_args(f1, iter=list(x=1), const=list(y=1)))

    f2 = function(x, ...) x
    expect_is(check_args(f2, iter=list(x=1, y=1)), "data.frame")
    expect_is(check_args(f2, iter=list(x=1), const=list(y=1)), "data.frame")
})

test_that("allow 1 non-optional unnamed arg", {
    f1 = function(x) x
    f2 = function(x, y=1) x+y
    f3 = function(x, y) x+y

    # allow 1 unnamed arg, but not wrong name
    expect_is(check_args(f1, iter=list(1)), "data.frame")
    expect_is(check_args(f2, iter=list(1)), "data.frame")
    expect_error(check_args(f3, iter=list(1)))
})
