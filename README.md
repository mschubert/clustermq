High performance computing / LSF jobs
=====================================

This script uses the [BatchJobs package](bj) to run functions either locally, on
multiple cores, or LSF, depending on your configuration. It has a simpler
interface, does more error checking than the library itself, and is able to
queue different function calls before waiting for the results. The function
supplied **must** be self-sufficient, i.e. load libraries and scripts.

### Usage

 * **Q()**      - create a new registry with that vectorises a function call and
   optionally runs it
 * **Qrun()**   - run all registries in the current working directory
 * **Qget()**   - extract the results from the registry and returns them
 * **Qclean()** - delete all registries in the current working directory
 * **Qregs()**  - list all registries in the current working directory

### Examples

```r
library(modules)
hpc = import('hpc')
s = function(x) x
hpc$Q(s, x=c(1:3)) # list(1,2,3)
```

```r
t = function(x) sum(x)
a = matrix(3:6, nrow=2)
hpc$Q(t, a) # splits a by columns
hpc$Qget() # list(7, 11)
```

[bj]: https://github.com/tudo-r/BatchJobs
