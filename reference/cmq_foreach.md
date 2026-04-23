# clustermq foreach handler

clustermq foreach handler

## Usage

``` r
cmq_foreach(obj, expr, envir, data)
```

## Arguments

- obj:

  Returned from foreach::foreach, containing the following variables:
  args : Arguments passed, each as a call argnames: character vector of
  arguments passed evalenv : Environment where to evaluate the arguments
  export : character vector of variable names to export to nodes
  packages: character vector of required packages verbose : whether to
  print status messages \[logical\] errorHandling: string of function
  name to call error with, e.g. "stop"

- expr:

  An R expression in curly braces

- envir:

  Environment where to evaluate the arguments

- data:

  Common arguments passed by register_dopcar_cmq(), e.g. n_jobs
