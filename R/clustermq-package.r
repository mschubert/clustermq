#' Evaluate Function Calls on HPC Schedulers (LSF, SGE, SLURM)
#'
#' Provides the \code{Q} function to send arbitrary function calls to
#' workers on HPC schedulers without relying on network-mounted storage.
#' Allows using remote schedulers via SSH.
#'
#' Under the hood, this will submit a cluster job that connects to the master
#' via TCP the master will then send the function and argument chunks to the
#' worker and the worker will return the results to the master until everything
#' is done and you get back your result
#'
#' Computations are done entirely on the network and without any temporary
#' files on network-mounted storage, so there is no strain on the file system
#' apart from starting up R once per job. This removes the biggest bottleneck
#' in distributed computing.
#'
#' Using this approach, we can easily do load-balancing, i.e. workers that get
#' their jobs done faster will also receive more function calls to work on. This
#' is especially useful if not all calls return after the same time, or one
#' worker has a high load.
#'
#' For more detailed usage instructions, see the documentation of the \code{Q}
#' function.
#'
#' @name clustermq
#' @docType package
NULL

#' Message ID indicating worker is accepting jobs
#'
#' Field has to be `worker_id` to master or empty to ssh_proxy
#' Answer is serialized common data (`fun`, `const`, and `seed`)
#' or `redirect` (with URL where worker can get data)
WORKER_UP = 10L

#' Message ID indicating worker is accepting jobs
#'
#' It may contain the field `result` with a finished chunk
WORKER_READY = 11L

#' Message ID indicating worker is shutting down
#'
#' Field has to be `time` with a object returned by `Sys.time()`
WORKER_DONE = 12L

#' Message ID telling worker to stop
#'
#' No fields
WORKER_STOP = 13L

#' Message ID indicating SSH proxy is up
PROXY_UP = 20L

#' Message ID indicating SSH proxy is ready to distribute data
#'
#' Field has to be `proxy`
PROXY_READY = 21L

#' Message telling the SSH proxy to clean up
#'
#' No fields. Signals the worker to break its main loop.
PROXY_STOP = 22L

#' Message is an SSH command
#'
#' Field is either `exec` (command to run) or `reply` (how it went)
PROXY_CMD = -24L

#' Chunk of iterated arguments for the worker
#'
#' Field has to be `chunk`
DO_CHUNK = 30L
