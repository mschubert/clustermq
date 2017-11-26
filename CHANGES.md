* 0.8.1
  * Fix performance issues for a high number of function calls (#56)
  * Fix bug where multicore workers were not shut down properly (#58)
  * Fix default templates for SGE, LSF and SLURM (misplaced quote)

* 0.8.0
  * Templates changed: `clustermq:::worker` now takes only master as argument
  * Fix a bug where copies of `common_data` are collected by gc too slowly (#19)
  * Creating `workers` is now separated from `Q`, enabling worker reuse (#45)
  * Objects in the function environment must now be `export`ed explicitly (#47)
  * Messages on the master are now processed in threads (#42)
  * Added `multicore` qsys using the `parallel` package (#49)
  * New function `Q_rows` using data.frame rows as iterated arguments (#43)
  * Jobs will now be submitted as array if possible
  * Job summary will now report max memory as reported by `gc` (#18)

* 0.7.0
  * Initial release on CRAN
