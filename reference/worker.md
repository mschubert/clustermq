# R worker submitted as cluster job

Do not call this manually, the master will do that

## Usage

``` r
worker(master, ..., verbose = TRUE, context = NULL)
```

## Arguments

- master:

  The master address (tcp://ip:port)

- ...:

  Catch-all to not break older template values (ignored)

- verbose:

  Whether to print debug messages

- context:

  ZeroMQ context (for internal testing)
