context("fill template")

test_that("missing values raise errors", {
    expect_error(fill_template("{{ unknown }} clustermq:::worker('tcp://m:p')",
                               "tcp://master:port"))
})

#test_that("call to worker is valid", {
#    expect_error(fill_template("clustermq:::worker('invalid')", "tcp://m:p"))
#    expect_error(fill_template("clustermq:::worker()", "tcp://m:p"))
#    expect_error(fill_template("clustermq:::worker('{{ master }}', {{ mem }})",
#                               "tcp://m:p", mem=1024))
#
#    expect_error(fill_template("clustermq:::worker({{ master }})", "tcp://m:p"))
#    expect_error(fill_template("worker('{{ master }}')", "tcp://m:p"))
#
#    expect_is(fill_template("clustermq:::worker('{{ master }}')", "tcp://m:p"),
#              'character')
#    expect_is(fill_template("clustermq:::worker('{{ master }}')", "inproc://p"),
#              'character')
#}

test_that("package templates", {
    expect_is(fill_template(LSF$template, "tcp://master:port", n_jobs=1),
              'character')
    expect_is(fill_template(SGE$template, "tcp://master:port", n_jobs=1),
              'character')
    expect_is(fill_template(SLURM$template, "tcp://master:port", n_jobs=1),
              'character')
})
