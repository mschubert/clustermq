# Function to process a chunk of calls

Each chunk comes encapsulated in a data.frame

## Usage

``` r
work_chunk(
  df,
  fun,
  const = list(),
  rettype = "list",
  common_seed = NULL,
  progress = FALSE
)
```

## Arguments

- df:

  A data.frame with call IDs as rownames and arguments as columns

- fun:

  The function to call

- const:

  Constant arguments passed to each call

- rettype:

  Return type of function

- common_seed:

  A seed offset common to all function calls

- progress:

  Logical indicated whether to display a progress bar

## Value

A list of call results (or try-error if they failed)
