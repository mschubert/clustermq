context("Q_call_index")

test_that("simple iter", {
    df = Q_call_index(iter=list(`a `=1:2, b=letters[1:2]))

    expect_equal(df$`a `, 1:2)
    expect_equal(df$b, letters[1:2])
    expect_equal(rownames(df), as.character(seq_len(nrow(df))))
    expect_equal(colnames(df), c('a ','b'))

    expect_error(Q_call_index(iter=list(a=1:3, b=letters[1:2])))
})

test_that("expand_grid", {
    df = Q_call_index(iter=list(a=1:3, b=letters[1:2]), expand_grid=TRUE)

    expect_equal(df$a, rep(1:3, 2))
    expect_equal(df$b, rep(letters[1:2], each=3))
    expect_equal(rownames(df), as.character(seq_len(3*2)))
    expect_equal(colnames(df), letters[1:2])
})

test_that("nested df", {
    df1 = data.frame(a=1:2, b=letters[1:2])
    df2 = Q_call_index(iter=list(a=1:3,b=list(df1)))

    expect_equal(nrow(df2), 3)
    expect_equal(df2$a, 1:3)
    expect_equal(df1, df2$b[[1]], df$b[[2]], df2$b[[3]],
                 tolerance=.Machine$double.eps, scale=NULL)
})

test_that("array splitting", {
    mat = matrix(1:4, nrow=2)

    df = Q_call_index(iter=list(a=mat))
    expect_equal(cbind(df$a[[1]], df$a[[2]]), mat)

    df = Q_call_index(iter=list(a=mat), split_array_by=1)
    expect_equal(rbind(df$a[[1]], df$a[[2]]), mat)
})
