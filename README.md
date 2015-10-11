High performance computing / LSF jobs
=====================================

This script uses the [rzmq package](https://github.com/armstrtw/rzmq) to run
function calls as LSF jobs. This is using the same library ([ZeroMQ](http://zeromq.org/))
that is also used for workers in IPython.

The function supplied **must be self-sufficient**, i.e. load libraries and scripts.

### `Q()`

Creates a new registry with that vectorises a function call and returns 
results if `get=T` (default).

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
