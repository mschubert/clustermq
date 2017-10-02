context("check_args")

test_that("required args are provided", {
    f1 = function(x) x
    expect_is(check_args(f1, iter=list(x=1)), "NULL")

    # allow 1 unnamed arg, but not wrong name
    expect_is(check_args(f1, iter=list(1)), "NULL")
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
    expect_is(check_args(f2, iter=list(x=1, y=1)), "NULL")
    expect_is(check_args(f2, iter=list(x=1), const=list(y=1)), "NULL")
})
