.PHONY: all
all: doc vignettes

R = R --no-save --no-restore -e
BIN = $(abspath $(lastword $(MAKEFILE_LIST))/../tests/bin)

.PHONY: test
test:
	PATH=$(BIN):$$PATH $(R) "devtools::test()"

.PHONY: check
check:
	PATH=$(BIN):$$PATH $(R) "devtools::check()"

rmd_files=$(wildcard vignettes/*.rmd)
knit_results=$(patsubst vignettes/%.rmd,inst/doc/%.md,$(rmd_files))

.PHONY: vignettes
vignettes: inst/doc ${knit_results}
	$(R) "library(knitr); library(devtools); build_vignettes()"

inst/doc:
	mkdir -p $@

inst/doc/%.md: vignettes/%.rmd
	$(R) "knitr::knit('$<', '$@')"

.PHONY: doc
doc:
	$(R) "devtools::document()"

.PHONY: clean
clean:
	${RM} -r inst/doc
	${RM} -r man
