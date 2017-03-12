context("Q_check")

test_that("required args are provided", {
    f1 = function(x) x
    expect_error(Q_check(f1, iter=list(x=1)), NA)

    # allow 1 unnamed arg, but not wrong name
    expect_error(Q_check(f1, iter=list(1)), NA)
    expect_error(Q_check(f1, iter=list(y=1)))

    # don't allow empty iter argument
    expect_error(Q_check(f1, iter=list()))
    expect_error(Q_check(f1, const=list(x=1)))
})

test_that("no superfluous args unless ...", {
    f1 = function(x) x
    expect_error(Q_check(f1, iter=list(x=1, y=1)))
    expect_error(Q_check(f1, iter=list(x=1), const=list(y=1)))

    f2 = function(x, ...) x
    expect_error(Q_check(f2, iter=list(x=1, y=1)), NA)
    expect_error(Q_check(f2, iter=list(x=1), const=list(y=1)), NA)
})
