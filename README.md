ClusterMQ: send R function calls as cluster jobs
================================================

[![Build Status](https://travis-ci.org/mschubert/clustermq.svg?branch=master)](https://travis-ci.org/mschubert/clustermq)
[![CRAN version](http://www.r-pkg.org/badges/version/clustermq)](https://cran.r-project.org/package=clustermq)

This package will allow you to send function calls as cluster jobs (using
[LSF](https://github.com/mschubert/clustermq/wiki/LSF),
[SGE](https://github.com/mschubert/clustermq/wiki/SGE) or
[SLURM](https://github.com/mschubert/clustermq/wiki/SLURM))
using a minimal interface provided by the `Q` function:

```r
# load the library and create a simple function
library(clustermq)
fx = function(x) x * 2

# queue the function call 
Q(fx, x=1:3, n_jobs=1)

# list(2,4,6)

# this will submit a cluster job that connects to the master via TCP
# the master will then send the function and argument chunks to the worker
# and the worker will return the results to the master
# until everything is done and you get back your result

# we can also use dplyr's mutate to modify data frames
library(dplyr)
iris %>%
    mutate(area = Q(`*`, e1=Sepal.Length, e2=Sepal.Width, n_jobs=1))
```

Computations are done [entirely on the
network](https://github.com/armstrtw/rzmq) and without any temporary files on
network-mounted storage, so there is no strain on the file system apart from
starting up R once per job. This removes the biggest bottleneck in distributed
computing.

Using this approach, we can easily do load-balancing, i.e. workers that get
their jobs done faster will also receive more function calls to work on. This
is especially useful if not all calls return after the same time, or one worker
has a high load.

Installation
------------

```r
# install.packages('devtools')
devtools::install_github('mschubert/clustermq')
devtools::install_github('krlmlr/ulimit') # protect workers from memory overflow
```

Then [set up your scheduler](https://github.com/mschubert/clustermq/wiki#setting-up-the-scheduler),
or else the package will warn you and continue with default values.

Usage
-----

The following arguments are supported by `Q`:

 * `fun` - The function to call. This needs to be self-sufficient (because it
        will not have access to the `master` environment)
 * `...` - All iterated arguments passed to the function. If there is more than
        one, all of them need to be named
 * `const` - A named list of non-iterated arguments passed to `fun`
 * `expand_grid` - Whether to use every combination of `...`

Behavior can further be fine-tuned using the options below:

 * `fail_on_error` - Whether to stop if one of the calls returns an error
 * `seed` - A common seed that is combined with job number for reproducible results
 * `scheduler_args` - Named list of template values to fill
 * `memory` - Shorthand for `scheduler_args=list(memory=...)`
 * `n_jobs` - Number of jobs to submit for all the function calls
 * `job_size` - Number of function calls per job. If used in combination with
        `n_jobs` the latter will be overall limit
 * `chunk_size` - How many calls a worker should process before reporting back
        to the master. Default: every worker will report back 100 times total
 * `wait_time` - How long the master should wait between checking for results

Comparison to other packages
----------------------------

There are some packages that provide high-level parallelization of R function calls
on a computing cluster. A thorough comparison of features and performance is available
[on the wiki](https://github.com/mschubert/clustermq/wiki#comparison-to-other-packages).

In short, use `ClusterMQ` if you want:

* a one-line solution to run cluster jobs with minimal setup
* access cluster functions from your local Rstudio via SSH
* network storage I/O is a problem for you(r cluster)
* your function calls or some workers are (much) slower than others

Use [`batchtools`](https://github.com/mllg/batchtools) if you:

* want to use a mature and well-tested package
* want more control over how your jobs are run
* don't mind a few extra lines to register and schedule your jobs

Use [Snakemake](https://snakemake.readthedocs.io/en/latest/) (or
[`flowr`](https://github.com/sahilseth/flowr),
[`remake`](https://github.com/richfitz/remake)) if:

* you want to design and run a pipeline of different tools

Don't use [`batch`](https://cran.r-project.org/web/packages/batch/index.html)
(last updated 2013) or [`BatchJobs`](https://github.com/tudo-r/BatchJobs)
(issues with SQLite on network-mounted storage).
