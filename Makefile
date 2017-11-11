.PHONY: all
all: documentation vignettes

R = Rscript --no-save --no-restore -e

test:
	$(R) "devtools::test()"

.PHONY: vignettes
vignettes: knit_all
	$(R) "library(knitr); library(devtools); build_vignettes()"

rmd_files=$(wildcard vignettes/*.rmd)
knit_results=$(patsubst vignettes/%.rmd,inst/doc/%.md,$(rmd_files))

.PHONY: knit_all
knit_all: inst/doc ${knit_results}
	cp -r vignettes/* inst/doc/

inst/doc:
	mkdir -p $@

inst/doc/%.md: vignettes/%.rmd
	$(R) "knitr::knit('$<', '$@')"

.PHONY: documentation
documentation:
	$(R) "devtools::document()"

cleanall:
	${RM} -r inst/doc
	${RM} -r man
