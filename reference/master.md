# Master controlling the workers

exchanging messages between the master and workers works the following
way: \* we have submitted a job where we don't know when it will start
up \* it starts, sends is a message list(id=0) indicating it is ready \*
we send it the function definition and common data \* we also send it
the first data set to work on \* when we get any id \> 0, it is a result
that we store \* and send the next data set/index to work on \* when
computatons are complete, we send id=0 to the worker \* it responds with
id=-1 (and usage stats) and shuts down

## Usage

``` r
master(
  pool,
  iter,
  rettype = "list",
  fail_on_error = TRUE,
  chunk_size = NA,
  timeout = Inf,
  max_calls_worker = Inf,
  verbose = TRUE
)
```

## Arguments

- pool:

  Instance of Pool object

- iter:

  Objects to be iterated in each function call

- rettype:

  Return type of function

- fail_on_error:

  If an error occurs on the workers, continue or fail?

- chunk_size:

  Number of function calls to chunk together defaults to 100 chunks per
  worker or max. 500 kb per chunk

- timeout:

  Maximum time in seconds to wait for worker (default: Inf)

- max_calls_worker:

  Maxmimum number of function calls that will be sent to one worker

- verbose:

  Print progress messages

## Value

A list of whatever \`fun\` returned
