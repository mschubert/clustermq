# SSH proxy for different schedulers

Do not call this manually, the SSH qsys will do that

## Usage

``` r
ssh_proxy(fwd_port, qsys_id = qsys_default)
```

## Arguments

- fwd_port:

  The port of the master address to connect to (remote end of reverse
  tunnel)

- qsys_id:

  Character string of QSys class to use
