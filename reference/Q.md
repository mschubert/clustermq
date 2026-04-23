# Queue function calls on the cluster

Queue function calls on the cluster

## Usage

``` r
Q(
  fun,
  ...,
  const = list(),
  export = list(),
  pkgs = c(),
  seed = 128965,
  memory = NULL,
  template = list(),
  n_jobs = NULL,
  job_size = NULL,
  rettype = "list",
  fail_on_error = TRUE,
  workers = NULL,
  log_worker = FALSE,
  chunk_size = NA,
  timeout = Inf,
  max_calls_worker = Inf,
  verbose = TRUE
)
```

## Arguments

- fun:

  A function to call

- ...:

  Objects to be iterated in each function call

- const:

  A list of constant arguments passed to each function call

- export:

  List of objects to be exported to the worker

- pkgs:

  Character vector of packages to load on the worker

- seed:

  A seed to set for each function call

- memory:

  Short for \`template=list(memory=value)\`

- template:

  A named list of values to fill in the scheduler template

- n_jobs:

  The number of jobs to submit; upper limit of jobs if job_size is given
  as well

- job_size:

  The number of function calls per job

- rettype:

  Return type of function call (vector type or 'list')

- fail_on_error:

  If an error occurs on the workers, continue or fail?

- workers:

  Optional instance of QSys representing a worker pool

- log_worker:

  Write a log file for each worker

- chunk_size:

  Number of function calls to chunk together defaults to 100 chunks per
  worker or max. 10 kb per chunk

- timeout:

  Maximum time in seconds to wait for worker (default: Inf)

- max_calls_worker:

  Maxmimum number of chunks that will be sent to one worker

- verbose:

  Print status messages and progress bar (default: TRUE)

## Value

A list of whatever \`fun\` returned

## Examples

``` r
if (FALSE) { # \dontrun{
# Run a simple multiplication for numbers 1 to 3 on a worker node
fx = function(x) x * 2
Q(fx, x=1:3, n_jobs=1)
# list(2,4,6)

# Run a mutate() call in dplyr on a worker node
iris %>%
    mutate(area = Q(`*`, e1=Sepal.Length, e2=Sepal.Width, n_jobs=1))
# iris with an additional column 'area'
} # }
```
