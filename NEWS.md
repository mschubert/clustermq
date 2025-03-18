# clustermq 0.9.8

* Suppress R6 clonable message
* Fix CRAN warning about `cppzmq` deprecated declaration

# clustermq 0.9.7

* Fix a bug where `BiocGenerics` could break template filling (#337)
* Remove deprecated automatic array splitting in `Q`

# clustermq 0.9.6

* Large common data size is now reported correctly (#336)
* Template filling will no longer convert large numbers to scientific format
* Common data will no longer be duplicated when sending to workers

# clustermq 0.9.5

* Fix a bug where an outdated system `libzmq` led to compilation errors (#327)
* New option `clustermq.ports` specifies eligible port range (#328) @michaelmayer2

# clustermq 0.9.4

* Fix a bug where worker stats were shown as `NA` (#325)
* Worker API: `env()` now visibly lists environment if called without arguments

# clustermq 0.9.3

* Fix a bug where `BiocParallel` did not export required objects (#302)
* Fix a bug where already finished workers were killed (#307)
* Fix a bug where worker results and stats could be garbage collected (#324)
* There is now an FAQ vignette with answers to frequently asked questions
* Worker API: `send()` now reports a call identifier that `current()` tracks

# clustermq 0.9.2

* Fix a bug where SSH proxy would not cache data properly (#320)
* Fix a bug where `max_calls_worker` was not respected (#322)
* Local parallelism (`multicore`, `multiprocess`) again uses local IP (#321)
* Worker API: `info()` now also returns current worker and number of calls

# clustermq 0.9.1

* Disconnect monitor (libzmq with `-DZMQ_BUILD_DRAFT_API=1`) is now optional (#317)
* Fix a bug where worker shutdown notifications can cause a crash (#306, #308, #310)
* Fix a bug where template values were not filled correctly (#309)
* Fix a bug where using `Rf_error` lead to improper cleanup of resources (#311)
* Fix a bug where maximum worker timeout was multiplied and led to undefined behavior
* Fix a bug where ZeroMQ's `-Werror` flag led to compilation issues on M1 Mac
* Fix a bug where SSH tests could error with timeout on high load
* Worker API: `CMQMaster` now needs to know `add_pending_workers(n)`
* Worker API: status report `info()` now displays properly

# clustermq 0.9.0

#### Features

* Reuse of common data is now supported (#154)
* Jobs now error instead of stalling upon unexpected worker disconnect (#150)
* Workers now error if they can not establish a connection within a time limit
* Error if `n_jobs` and `max_calls_worker` provide insufficient call slots (#258)
* Request 1 GB by default in SGE template (#298) @nickholway
* Error and warning summary now orders by index and severity (#304)
* A call can have multiple warnings forwarded, not only last

#### Bugfix

* Fix bug where max memory reporting by `gc()` may be in different column (#240)
* Fix passing numerical `job_id` to `qdel` in PBS (#265)
* The job port/id pool is now used properly upon binding failure (#270) @luwidmer
* Common data size warning is now only displayed when exceeding limits (#287)

#### Internal

* Complete rewrite of the worker API
* We no longer depend on the `purrr` package

# clustermq 0.8.95

* We are now using _ZeroMQ_ via `Rcpp` in preparation for `v0.9` (#151)
* New `multiprocess` backend via `callr` instead of forking (#142, #197)
* Sending data on sockets is now blocking to avoid excess memory usage (#161)
* `multicore`, `multiprocess` schedulers now support logging (#169)
* New option `clustermq.host` can specify host IP or network interface name (#170)
* Template filling will now raise error for missing keys (#174, #198)
* Workers failing with large common data is improved (fixed?) (#146, #179, #191)
* Local connections are now routed via `127.0.0.1` instead of `localhost` (#192)
* Submit messages are different between local, multicore and HPC (#196)
* Functions exported by `foreach` now have their environment stripped (#200)
* Deprecation of `log_worker=T/F` argument is rescinded

# clustermq 0.8.9

* New option `clustermq.ssh.timeout` for SSH proxy startup (#157) @brendanf
* New option `clustermq.worker.timeout` for delay before worker shutdown (#188)
* Fixed PBS/Torque docs, template and cleanup (#184, #186) @mstr3336
* Warning if common data is very large, set by `clustermq.data.warning` (#189)

# clustermq 0.8.8

* `Q`, `Q_rows` have new arguments `verbose` (#111) and `pkgs` (#144)
* `foreach` backend now uses its dedicated API where possible (#143, #144)
* Number and size of objects common to all calls now work properly
* Templates are filled internally and no longer depend on `infuser` package

# clustermq 0.8.7

* `Q` now has `max_calls_worker` argument to avoid walltime (#110)
* Submission messages now list size of common data (drake#800)
* All default templates now have an optional `cores` per job field (#123)
* `foreach` now treats `.export` (#124) and `.combine` (#126) correctly
* New option `clustermq.error.timeout` to not wait for clean shutdown (#134)
* SSH command is now specified via a template file (#122)
* SSH will now forward errors to the local process (#135)
* The Wiki is deprecated, use https://mschubert.github.io/clustermq/ instead

# clustermq 0.8.6

* Progress bar is now shown before any workers start (#107)
* Socket connections are now authenticated using a session password (#125)
* Marked internal functions with `@keywords internal`
* Added vignettes for the _User Guide_ and _Technical Documentation_

# clustermq 0.8.5

* Added experimental support as parallel foreach backend (#83)
* Moved templates to package `inst/` directory (#85)
* Added `send_call` to worker to evaluate arbitrary expressions (drake#501; #86)
* Option `clustermq.scheduler` is now respected if set after package load (#88)
* System interrupts are now handled correctly (rzmq#44; #73, #93, #97)
* Number of workers running/total is now shown in progress bar (#98)
* Unqualified (short) host names are now resolved by default (#104)

# clustermq 0.8.4

* Fix error for `qsys$reusable` when using `n_jobs=0`/local processing (#75)
* Scheduler-specific templates are deprecated. Use `clustermq.template` instead
* Allow option `clustermq.defaults` to fill default template values (#71)
* Errors in worker processing are now shut down cleanly (#67)
* Progress bar now shows estimated time remaining (#66)
* Progress bar now also shown when processing locally
* Memory summary now adds estimated memory of R session (#69)

# clustermq 0.8.3

* Support `rettype` for function calls where return type is known (#59)
* Reduce memory requirements by processing results when we receive them
* Fix a bug where cleanup, `log_worker` flag were not working for SGE/SLURM

# clustermq 0.8.2

* Fix a bug where never-started jobs are not cleaned up
* Fix a bug where tests leave processes if port binding fails (#60)
* Multicore no longer prints worker debug messages (#61)

# clustermq 0.8.1

* Fix performance issues for a high number of function calls (#56)
* Fix bug where multicore workers were not shut down properly (#58)
* Fix default templates for SGE, LSF and SLURM (misplaced quote)

# clustermq 0.8.0

#### Features

* Templates changed: `clustermq:::worker` now takes only master as argument
* Creating `workers` is now separated from `Q`, enabling worker reuse (#45)
* Objects in the function environment must now be `export`ed explicitly (#47)
* Added `multicore` qsys using the `parallel` package (#49)
* New function `Q_rows` using data.frame rows as iterated arguments (#43)
* Job summary will now report max memory as reported by `gc` (#18)

#### Bugfix

* Fix a bug where copies of `common_data` are collected by gc too slowly (#19)

#### Internal

* Messages on the master are now processed in threads (#42)
* Jobs will now be submitted as array if possible

# clustermq 0.7.0

* Initial release on CRAN
