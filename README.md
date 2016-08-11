ClusterMQ: send R function calls as LSF jobs
============================================

This package will allow you to send function calls as LSF jobs using a minimal
interface provided by the `Q` function:

```r
# load the library and create a simple function
library(clustermq)
fx = function(x) x * 2

# queue the function call 
Q(fx, x=1:3, n_jobs=1)

# this will submit an LSF job that connects to the master via TCP
# the master will then send the function and argument chunks to the worker
# and the worker will return the results to the master
# until everything is done and you get back your result

# list(2,4,6)
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

Then [set up your scheduler](https://github.com/mschubert/clustermq/wiki#setting-up-the-scheduler)
(currently only LSF), or else the package will warn you and continue with
default values.

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
 * `memory` - Amount of memory to request for the job (`bsub -M`)
 * `n_jobs` - Number of jobs to submit for all the function calls
 * `job_size` - Number of function calls per job. If used in combination with
        `n_jobs` the latter will be overall limit
 * `chunk_size` - How many calls a worker should process before reporting back
        to the master. Default: every worker will report back 100 times total
 * `wait_time` - How long the master should wait between checking for results

Performance
-----------

It's a lot faster than `BatchJobs` for short function calls because it doesn't
start a new instance of R with every call. I've successfully used it with 10<sup>
8</sup> function calls where the former did not process 10<sup>6</sup>.

It also bypasses network-mounted storage entirely by sendign all data directly
via TCP and performs load balancing that is useful if calls take different
amounts of time or some workers are slower than others.
