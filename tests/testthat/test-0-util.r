context("util")

test_that("template filler", {
    tmpl = "this is my {{ template }}"
    values = list(template = "filled")

    filled = fill_template(tmpl, values)
    expect_equal(filled, "this is my filled")

    expect_error(fill_template(tmpl, list(key="unrelated")))
})

test_that("template default values", {
    tmpl = "this is my {{ template | default }}"
    values = list(template = "filled")

    filled1 = fill_template(tmpl, values)
    expect_equal(filled1, "this is my filled")

    filled2 = fill_template(tmpl, list())
    expect_equal(filled2, "this is my default")
})

test_that("template required key", {
    tmpl = "this is my {{ template }}"
    values = list(template = "filled")

    expect_error(fill_template(tmpl, values, required="missing"))
})
