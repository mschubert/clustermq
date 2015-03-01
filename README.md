High performance computing / LSF jobs
=====================================

This script uses the [BatchJobs package](https://github.com/tudo-r/BatchJobs) to run functions either locally, on
multiple cores, or LSF, depending on your configuration. It has a simpler
interface, does more error checking than the library itself, and is able to
queue different function calls before waiting for the results. The function
supplied **must be self-sufficient**, i.e. load libraries and scripts.

**Note: there are some issues with RSQLite>=1.0, use the following:**

```bash
wget http://cran.r-project.org/src/contrib/Archive/RSQLite/RSQLite_0.11.4.tar.gz
wget http://cran.r-project.org/src/contrib/Archive/BatchJobs/BatchJobs_1.4.tar.gz
R CMD INSTALL RSQLite_0.11.4.tar.gz BatchJobs_1.4.tar.gz
```

### `Q()`

Creates a new registry with that vectorises a function call and returns 
results if `get=T` (default).

```r
library(modules)
hpc = import('hpc')
s = function(x) x
hpc$Q(s, x=c(1:3)) # list(1,2,3)
```

```r
t = function(x) sum(x)
a = matrix(3:6, nrow=2)
hpc$Q(t, a) # splits a by columns: list(7, 11)
```
