# Print a summary of errors and warnings that occurred during processing

Print a summary of errors and warnings that occurred during processing

## Usage

``` r
summarize_result(
  result,
  n_errors,
  n_warnings,
  cond_msgs,
  at = length(result),
  fail_on_error = TRUE
)
```

## Arguments

- result:

  A list or vector of the processing result

- n_errors:

  How many errors occurred

- n_warnings:

  How many warnings occurred

- cond_msgs:

  Error and warnings messages, we display first 50

- at:

  How many calls were procesed up to this point

- fail_on_error:

  Stop if error(s) occurred
