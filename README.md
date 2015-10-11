High performance computing / LSF jobs
=====================================

Perform function calls in LSF jobs. The module will start `n_jobs` LSF jobs (workers) with the
memory requirements specified, and then send `<i>` function calls to those workers.

This is done entirely on the network and without temporary files (unless `log_worker=TRUE`),
so there is no strain on the file system apart from starting up R once per LSF job.

The module also performs load-balancing, i.e. workers that get their jobs done faster will also
receive more function calls to work on. This is especially useful if not all calls
return after the same time, or one worker has a high load. For long running jobs use `n_jobs=<i>`.

It is based upon the [rzmq package](https://github.com/armstrtw/rzmq) and the
[ZeroMQ library](http://zeromq.org/) that is also used for workers in IPython.

The function supplied **must be self-sufficient**, i.e. load libraries and scripts.

### `Q()`

```r
hpc = import('hpc')
s = function(x) x
hpc$Q(s, x=c(1:3), n_jobs=1) # list(1,2,3)
```

```r
t = function(x) sum(x)
a = matrix(3:6, nrow=2)
hpc$Q(t, a, n_jobs=1) # splits a by columns: list(7, 11)
```
