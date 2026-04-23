# Creates a pool of workers

Creates a pool of workers

## Usage

``` r
workers(
  n_jobs,
  data = NULL,
  reuse = TRUE,
  template = list(),
  log_worker = FALSE,
  qsys_id = getOption("clustermq.scheduler", qsys_default),
  verbose = FALSE,
  ...
)
```

## Arguments

- n_jobs:

  Number of jobs to submit (0 implies local processing)

- data:

  Set common data (function, constant args, seed)

- reuse:

  Whether workers are reusable or get shut down after call

- template:

  A named list of values to fill in template

- log_worker:

  Write a log file for each worker

- qsys_id:

  Character string of QSys class to use

- verbose:

  Print message about worker startup

- ...:

  Additional arguments passed to the qsys constructor

## Value

An instance of the QSys class
