context("work_chunk")

df = as.data.frame(tibble::data_frame(
    a = 1:3,
    b = as.list(letters[1:3]),
    c = setNames(as.list(3:1), letters[1:3])
))

test_that("data types and arg names", {
    fx = function(c, a, b) a + c
    expect_equal(work_chunk(df, fx)$result,
                 setNames(as.list(rep(4,3)), rownames(df)))

    expect_equal(work_chunk(df, fx, rettype="numeric")$result,
                 setNames(rep(4,3), rownames(df)))
})

test_that("check call classes", {
    df2 = df
    df2$a = list(matrix(1:4, nrow=2))
    fx = function(...) sapply(list(...), class)

    re = setNames(c("matrix", "character", "integer"), c("a", "b", "c"))
    expect_equal(work_chunk(df2, fx)$result, setNames(rep(list(re), 3), c(1:3)))
})

test_that("do not unlist matrix in data.frame", {
    elm = structure(1:4, .Dim = c(2,2), .Dimnames=list(c("r1","r2"), c("c1","c2")))
    df2 = structure(list(expr = structure(list(expr = elm))))

    fx = function(...) list(...)
    expect_equal(work_chunk(df2, fx)$result$'1', list(expr=elm))
})

test_that("warning and error handling", {
    fx = function(a, ...) {
        if (a %% 3 == 0)
            warning("warning")
        if (a %% 2 == 0)
            stop("error")
        a
    }

    re = work_chunk(data.frame(a=1:6), fx)
    expect_equal(sapply(re$result, class) == "error",
                 setNames(rep(c(FALSE,TRUE), 3), 1:6))
    expect_equal(unname(unlist(re$result[c(1,3,5)])),
                 as.integer(names(re$result[c(1,3,5)])),
                 c(1,3,5))
    expect_equal(length(re$warnings), 2)
    expect_true(grepl("3", re$warnings[[1]]))
    expect_true(grepl("warning", re$warnings[[1]]))
    expect_true(grepl("6", re$warnings[[2]]))
    expect_true(grepl("warning", re$warnings[[2]]))
})

test_that("const args", {
    fx = function(a, ..., x=23) a + x

    re = work_chunk(df, fx, const=list(x=5))$result
    expect_equal(re, setNames(as.list(df$a + 5), 1:3))
})

test_that("seed reproducibility", {
    fx = function(a, ...) sample(1:1000, 1)
    
    # seed should be set by common + df row name
    expect_equal(work_chunk(df[1:2,], fx, common_seed=123)$result$'2',
                 work_chunk(df[2:3,], fx, common_seed=123)$result$'2')
})

test_that("env separation", {
    seed = 123
    fx = function(x, common_seed=seed) {
        fun = function(x) stop("overwrite function")
        df = data.frame()
        common_seed
    }
    df2 = data.frame(x=1:5)
    expect_equal(work_chunk(df2, fx)$result, setNames(rep(list(seed), 5), 1:5))
})
