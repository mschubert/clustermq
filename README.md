High performance computing / LSF jobs
=====================================

This script uses BatchJobs to run functions either locally, on multiple cores, or LSF,
depending on your BatchJobs configuration. It has a simpler interface, does more error
checking than the library itself, and is able to queue different function calls. The
function supplied **must** be self-sufficient, i.e. load libraries and scripts.

### Usage

 * **Q()**     : create a new registry with that vectorises a function call and optionally runs it
 * **Qrun()**  : run all registries in the current working directory
 * **Qget()**  : extract the results from the registry and returns them
 * **Qclean()**: delete all registries in the current working directory
 * **Qregs()** : list all registries in the current working directory

### Examples

```r
s = function(x) x
Q(s, x=c(1:3)) # list(1,2,3)
```

```r
t = function(x) sum(x)
a = matrix(3:6, nrow=2)
Q(t, a) # splits a by columns
Qget() # list(7, 11)
```
