ClusterMQ: send R function calls as LSF jobs
============================================

Rationale
---------

This package will allow you to send function calls as LSF jobs using a minimal
interface.

Computations are done entirely on the network and without any temporary files
on network-mounted storage, so there is no strain on the file system apart from
starting up R once per job. This removes the biggest bottleneck in distributed
computing, making it much faster.

Using this approach, we can easily do load-balancing, i.e. workers that get
their jobs done faster will also receive more function calls to work on. This
is especially useful if not all calls return after the same time, or one worker
has a high load.

Requirements
------------

Currently, only LSF is supported as a scheduler. Adding others should be
simple, but will only be implemented if there is a need for it.

The infrastructure is provided by [ZeroMQ](http://zeromq.org/) library,
provided by the [rzmq package](https://github.com/armstrtw/rzmq).

If the [ulimit package](https://github.com/krlmlr/ulimit) is available, workers
will be protected from crashing by running out of memory.

Usage
-----

```r
library(clustermq)
fx = function(x) x * 2
Q(fx, x=c(1:3), n_jobs=1) # list(1,2,3)
```

The following arguments are supported by `Q`:

 * `fun` - The function to call. This needs to be self-sufficient (because it
        will not have access to the `master` environment)
 * `...` - All iterated arguments passed to the function. If there is more than
        one, all of them need to be named
 * `const` - A named list of non-iterated arguments passed to `fun`
 * `expand_grid` - Whether to use every combination of `...`
 * `fail_on_error` - Whether to stop if one of the calls returns an error
 * `seed` - A common seed that is combined with job number for reproducible results
 * `memory` - Amount of memory to request for the job (`bsub -M`)
 * `n_jobs` - Number of jobs to submit for all the function calls
 * `job_size` - Number of function calls per job. If used in combination with
        `n_jobs` the latter will be overall limit
 * `chunk_size` - How many calls a worker should process before reporting back
        to the master. Default: every worker will report back 100 times total
 * `wait_time` - How long the master should wait between checking for results
 * `qsys` - The queuing system use. Currently only `"lsf"` is supported

Performance
-----------

It's a lot faster than `BatchJobs` for short function calls because it doesn't
start a new instance of R with every call.

It also bypasses network-mounted storage entirely by sendign all data directly
via TCP and performs load balancing that is useful if calls take different
amounts of time or some workers are slower than others.
