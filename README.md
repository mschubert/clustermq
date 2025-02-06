ClusterMQ: send R function calls as cluster jobs
================================================

[![CRAN version](https://www.r-pkg.org/badges/version/clustermq)](https://cran.r-project.org/package=clustermq)
[![Build Status](https://github.com/mschubert/clustermq/actions/workflows/check-standard.yaml/badge.svg)](https://github.com/mschubert/clustermq/actions)
[![CRAN downloads](https://cranlogs.r-pkg.org/badges/clustermq)](https://cran.r-project.org/package=clustermq)
[![DOI](https://zenodo.org/badge/DOI/10.1093/bioinformatics/btz284.svg)](https://doi.org/10.1093/bioinformatics/btz284)

This package will allow you to send function calls as jobs on a computing
cluster with a minimal interface provided by the `Q` function:

```r
# install the package if you haven't done so yet
install.packages('clustermq')

# load the library and create a simple function
library(clustermq)
fx = function(x) x * 2

# queue the function call on your scheduler
Q(fx, x=1:3, n_jobs=1)
# list(2,4,6)
```

Computations are done [entirely on the network](https://zeromq.org/)
and without any temporary files on network-mounted storage, so there is no
strain on the file system apart from starting up R once per job. All
calculations are load-balanced, i.e. workers that get their jobs done faster
will also receive more function calls to work on. This is especially useful if
not all calls return after the same time, or one worker has a high load.

Browse the vignettes here:

* [User Guide](https://mschubert.github.io/clustermq/articles/userguide.html)
* [Technical Documentation](https://mschubert.github.io/clustermq/articles/technicaldocs.html)
* [FAQ](https://mschubert.github.io/clustermq/articles/faq.html)

Schedulers
----------

An HPC cluster's scheduler ensures that computing jobs are distributed to
available worker nodes. Hence, this is what clustermq interfaces with in order
to do computations.

We currently support the [following
schedulers](https://mschubert.github.io/clustermq/articles/userguide.html#configuration)
(either locally or via SSH):

* [Multiprocess](https://mschubert.github.io/clustermq/articles/userguide.html#local-parallelization) -
  *test your calls and parallelize on cores using* `options(clustermq.scheduler="multiprocess")`
* [SLURM](https://mschubert.github.io/clustermq/articles/userguide.html#slurm) - *should work without setup*
* [LSF](https://mschubert.github.io/clustermq/articles/userguide.html#lsf) - *should work without setup*
* [SGE](https://mschubert.github.io/clustermq/articles/userguide.html#sge) - *may require configuration*
* [PBS](https://mschubert.github.io/clustermq/articles/userguide.html#pbs)/[Torque](https://mschubert.github.io/clustermq/articles/userguide.html#torque) - *needs* `options(clustermq.scheduler="PBS"/"Torque")`
* via [SSH](https://mschubert.github.io/clustermq/articles/userguide.html#ssh-connector) -
*needs* `options(clustermq.scheduler="ssh", clustermq.ssh.host=<yourhost>)`

> [!TIP]
> Follow the links above to configure your scheduler in case it is not working
> out of the box and check the
> [FAQ](https://mschubert.github.io/clustermq/articles/faq.html) if
> your job submission errors or gets stuck

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

We can also use `clustermq` as a parallel backend in
[`foreach`](https://cran.r-project.org/package=foreach) or
[`BiocParallel`](https://bioconductor.org/packages/release/bioc/html/BiocParallel.html):

```r
# using foreach
library(foreach)
register_dopar_cmq(n_jobs=2, memory=1024) # see `?workers` for arguments
foreach(i=1:3) %dopar% sqrt(i) # this will be executed as jobs

# using BiocParallel
library(BiocParallel)
register(DoparParam()) # after register_dopar_cmq(...)
bplapply(1:3, sqrt)
```

More examples are available in [the
User Guide](https://mschubert.github.io/clustermq/articles/userguide.html).

Comparison to other packages
----------------------------

There are some packages that provide high-level parallelization of R function calls
on a computing cluster. We compared `clustermq` to `BatchJobs` and `batchtools` for
processing many short-running jobs, and found it to have approximately 1000x less
overhead cost.

![Overhead comparison](http://image.ibb.co/cRgYNR/plot.png)

In short, use `clustermq` if you want:

* a one-line solution to run cluster jobs with minimal setup
* access cluster functions from your local Rstudio via SSH
* fast processing of many function calls without network storage I/O

Use [`batchtools`](https://github.com/mllg/batchtools) if you:

* want to use a mature and well-tested package
* don't mind that arguments to every call are written to/read from disc
* don't mind there's no load-balancing at run-time

Use [Snakemake](https://snakemake.readthedocs.io/en/latest/) or
[`targets`](https://github.com/ropensci/targets) if:

* you want to design and run a workflow on HPC

Don't use [`batch`](https://cran.r-project.org/package=batch)
(last updated 2013) or [`BatchJobs`](https://github.com/tudo-r/BatchJobs)
(issues with SQLite on network-mounted storage).

Contributing
------------

Contributions are welcome and they come in many different forms, shapes, and
sizes. These include, but are not limited to:

* **Questions**: Ask on the [Github
  Discussions](https://github.com/mschubert/clustermq/discussions) board. If
  you are an advanced user, please also consider answering questions there.
* **Bug reports**: [File an issue](https://github.com/mschubert/clustermq/issues)
  if something does not work as expected. Be sure to
  include a self-contained [Minimal Reproducible
  Example](https://stackoverflow.com/help/minimal-reproducible-example) and set
  `log_worker=TRUE`.
* **Code contributions**: Have a look at the [`good first
  issue`](https://github.com/mschubert/clustermq/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
  tag. Please discuss anything more complicated before putting a lot of work
  in, I'm happy to help you get started.

> [!TIP]
> Check the
> [User Guide](https://mschubert.github.io/clustermq/articles/userguide.html) and the
> [FAQ](https://mschubert.github.io/clustermq/articles/faq.html) first, maybe
> your query is already answered there

Citation
--------

This project is part of my academic work, for which I will be evaluated on
citations. If you like me to be able to continue working on research support
tools like `clustermq`, please cite the article when using it for publications:

> M Schubert. clustermq enables efficient parallelisation of genomic analyses.
> *Bioinformatics* (2019).
> [doi:10.1093/bioinformatics/btz284](https://doi.org/10.1093/bioinformatics/btz284)
