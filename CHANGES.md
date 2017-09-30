* 0.8.0
  * `common_data` is no longer copied each time it is sent (#19)
  * `create_worker_pool` is now separated from `Q`, enabling worker reuse (#45)
  * Objects in the function environment must now be `export`ed explicitly (#47)
  * Messages on the master are now processed in threads (#42)
  * Added `multicore` qsys using the `parallel` package (#49)
  * Jobs will now be submitted as array if possible

* 0.7.0
  * Initial release on CRAN
