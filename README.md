ClusterMQ: send R function calls as cluster jobs
================================================

[![CRAN version](http://www.r-pkg.org/badges/version/clustermq)](https://cran.r-project.org/package=clustermq)
[![Build Status](https://travis-ci.org/mschubert/clustermq.svg?branch=master)](https://travis-ci.org/mschubert/clustermq)
[![CRAN downloads](http://cranlogs.r-pkg.org/badges/clustermq)](http://cran.rstudio.com/web/packages/clustermq/index.html)

This package will allow you to send function calls as jobs on a computing
cluster with a minimal interface provided by the `Q` function:

```r
# load the library and create a simple function
library(clustermq)
fx = function(x) x * 2

# queue the function call on your scheduler
Q(fx, x=1:3, n_jobs=1)
# list(2,4,6)
```

Computations are done [entirely on the
network](https://github.com/armstrtw/rzmq) and without any temporary files on
network-mounted storage, so there is no strain on the file system apart from
starting up R once per job. This way, we can also send data and results around
a lot quicker.

All calculations are load-balanced, i.e. workers that get their jobs done
faster will also receive more function calls to work on. This is especially
useful if not all calls return after the same time, or one worker has a high
load.

Installation
------------

First, we need the [ZeroMQ](https://github.com/ropensci/rzmq#installation)
system library. Most likely, your package manager will provide this:

```sh
# You can skip this step on Windows and OS-X, the rzmq binary has it
# On a computing cluster, we recommend to use Conda or Linuxbrew
brew install zeromq # Linuxbrew, Homebrew on OS-X
conda install zeromq # Conda
sudo apt-get install libzmq3-dev # Ubuntu
sudo yum install zeromq3-devel # Fedora
pacman -S zeromq # Archlinux
```

Then install the `clustermq` package in R (which automatically installs the
`rzmq` package as well) from CRAN:

```r
install.packages('clustermq')
```

Alternatively you can use `devtools` to install directly from Github:

```r
# install.packages('devtools')
devtools::install_github('mschubert/clustermq')
# devtools::install_github('mschubert/clustermq', ref="develop") # dev version
```

Schedulers
----------

We currently support the [following
schedulers](https://github.com/mschubert/clustermq/wiki#setting-up-the-scheduler):

* [LSF](https://github.com/mschubert/clustermq/wiki/LSF) - *should work without setup*
* [SGE](https://github.com/mschubert/clustermq/wiki/SGE) - *should work without setup*
* [SLURM](https://github.com/mschubert/clustermq/wiki/SLURM) - *should work without setup*
* [PBS](https://github.com/mschubert/clustermq/wiki/PBS)/[Torque](https://github.com/mschubert/clustermq/wiki/Torque) - *needs SGE scheduler option and custom template*

You can also access each of these schedulers from your local machine via the
[SSH connector](https://github.com/mschubert/clustermq/wiki/SSH).

If you need specific [computing environments or
containers](https://github.com/mschubert/clustermq/wiki/Environments), you can
activate them via the scheduler template.

Usage
-----

The most common arguments for `Q` are:

 * `fun` - The function to call. This needs to be self-sufficient (because it
        will not have access to the `master` environment)
 * `...` - All iterated arguments passed to the function. If there is more than
        one, all of them need to be named
 * `const` - A named list of non-iterated arguments passed to `fun`
 * `export` - A named list of objects to export to the worker environment

The documentation for other arguments can be accessed by typing `?Q`. Examples
of using `const` and `export` would be:

```r
# adding a constant argument
fx = function(x, y) x * 2 + y
Q(fx, x=1:3, const=list(y=10), n_jobs=1)

# exporting an object to workers
fx = function(x) x * 2 + y
Q(fx, x=1:3, export=list(y=10), n_jobs=1)
```

More examples are available in [the
vignette](vignettes/clustermq.Rmd#examples). 

Comparison to other packages
----------------------------

There are some packages that provide high-level parallelization of R function calls
on a computing cluster. We compared `clustermq` to `BatchJobs` and `batchtools` for
processing many short-running jobs, and found it to have approximately 1000x less
overhead cost (details [on the wiki](https://github.com/mschubert/clustermq/wiki#comparison-to-other-packages)).

![Overhead comparison](http://image.ibb.co/cRgYNR/plot.png)

In short, use `ClusterMQ` if you want:

* a one-line solution to run cluster jobs with minimal setup
* access cluster functions from your local Rstudio via SSH
* fast processing of many function calls without network storage I/O

Use [`batchtools`](https://github.com/mllg/batchtools) if you:

* want to use a mature and well-tested package
* don't mind that arguments to every call are written to/read from disc
* don't mind there's no load-balancing at run-time

Use [Snakemake](https://snakemake.readthedocs.io/en/latest/) (or
[`flowr`](https://github.com/sahilseth/flowr),
[`remake`](https://github.com/richfitz/remake),
[`drake`](https://github.com/ropensci/drake)) if:

* you want to design and run a pipeline of different tools

Don't use [`batch`](https://cran.r-project.org/web/packages/batch/index.html)
(last updated 2013) or [`BatchJobs`](https://github.com/tudo-r/BatchJobs)
(issues with SQLite on network-mounted storage).
