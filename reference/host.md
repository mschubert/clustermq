# Construct the ZeroMQ host address

Construct the ZeroMQ host address

## Usage

``` r
host(
  node = getOption("clustermq.host", Sys.info()["nodename"]),
  ports = getOption("clustermq.ports", 6000:9999),
  n = 100
)
```

## Arguments

- node:

  Node or device name

- ports:

  Range of ports to consider

- n:

  How many addresses to return

## Value

The possible addresses as character vector
