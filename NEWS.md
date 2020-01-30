* New option `clustermq.ssh.timeout` to set timeout for SSH proxy startup. (#157)
* Fixed default PBS submission template and PBS/Torque documentation (#184) (@mstr3336)

# 0.8.8

* `Q`, `Q_rows` have new arguments `verbose` (#111) and `pkgs` (#144)
* `foreach` backend now uses its dedicated API where possible (#143, #144)
* Number and size of objects common to all calls now work properly
* Templates are filled internally and no longer depend on `infuser` package

# 0.8.7

* `Q` now has `max_calls_worker` argument to avoid walltime (#110)
* Submission messages now list size of common data (drake#800)
* All default templates now have an optional `cores` per job field (#123)
* `foreach` now treats `.export` (#124) and `.combine` (#126) correctly
* New option `clustermq.error.timeout` to not wait for clean shutdown (#134)
* SSH command is now specified via a template file (#122)
* SSH will now forward errors to the local process (#135)
* The Wiki is deprecated, use https://mschubert.github.io/clustermq/ instead

# 0.8.6

* Progress bar is now shown before any workers start (#107)
* Socket connections are now authenticated using a session password (#125)
* Marked internal functions with `@keywords internal`
* Added vignettes for the _User Guide_ and _Technical Documentation_

# 0.8.5

* Added experimental support as parallel foreach backend (#83)
* Moved templates to package `inst/` directory (#85)
* Added `send_call` to worker to evaluate arbitrary expressions (drake#501; #86)
* Option `clustermq.scheduler` is now respected if set after package load (#88)
* System interrupts are now handled correctly (rzmq#44; #73, #93, #97)
* Number of workers running/total is now shown in progress bar (#98)
* Unqualified (short) host names are now resolved by default (#104)

# 0.8.4

* Fix error for `qsys$reusable` when using `n_jobs=0`/local processing (#75)
* Scheduler-specific templates are deprecated. Use `clustermq.template` instead
* Allow option `clustermq.defaults` to fill default template values (#71)
* Errors in worker processing are now shut down cleanly (#67)
* Progress bar now shows estimated time remaining (#66)
* Progress bar now also shown when processing locally
* Memory summary now adds estimated memory of R session (#69)

# 0.8.3

* Support `rettype` for function calls where return type is known (#59)
* Reduce memory requirements by processing results when we receive them
* Fix a bug where cleanup, `log_worker` flag were not working for SGE/SLURM

# 0.8.2

* Fix a bug where never-started jobs are not cleaned up
* Fix a bug where tests leave processes if port binding fails (#60)
* Multicore no longer prints worker debug messages (#61)

# 0.8.1

* Fix performance issues for a high number of function calls (#56)
* Fix bug where multicore workers were not shut down properly (#58)
* Fix default templates for SGE, LSF and SLURM (misplaced quote)

# 0.8.0

* Templates changed: `clustermq:::worker` now takes only master as argument
* Fix a bug where copies of `common_data` are collected by gc too slowly (#19)
* Creating `workers` is now separated from `Q`, enabling worker reuse (#45)
* Objects in the function environment must now be `export`ed explicitly (#47)
* Messages on the master are now processed in threads (#42)
* Added `multicore` qsys using the `parallel` package (#49)
* New function `Q_rows` using data.frame rows as iterated arguments (#43)
* Jobs will now be submitted as array if possible
* Job summary will now report max memory as reported by `gc` (#18)

# 0.7.0

* Initial release on CRAN
