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

test_that("template filling works with vectors", {
    tmpl = "{{ var1 }} and {{ var2 }}"
    values = c(var1=1, var2=2)

    expect_equal(fill_template(tmpl, values), "1 and 2")
})

test_that("template numbers are not converted to sci format", {
    tmpl = "this is my {{ template }}"
    values = list(template = 100000)

    expect_equal(fill_template(tmpl, values), "this is my 100000")
})

test_that("no sci format when passing vectors", {
    tmpl = "{{ var1 }} and {{ var2 }}"
    values = c(var1=1, var2=1e6)

    expect_equal(fill_template(tmpl, values), "1 and 1000000")
})
