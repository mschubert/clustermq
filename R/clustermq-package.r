#' ZeroMQ-powered cluster jobs
#'
#' Rationale This script uses rzmq to run function calls as LSF jobs. The
#' function supplied *MUST* be self-sufficient, i.e. load libraries and
#' scripts.
#'
#' Usage
#'  * Q(...)     : general queuing function
#'
#' Examples
#'  > s = function(x) x
#'  > Q(s, x=c(1:3), n_jobs=1)
#'  returns list(1,2,3)
#'
#'  > t = function(x) sum(x)
#'  > a = matrix(3:6, nrow=2)
#'  > Q(t, a, n_jobs=1)
#'  splits a by columns, sums each column, and returns list(7, 11)
#'
#' TODO list
#'  * rerun failed jobs?
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
SSH_UP = 20L

#' Message ID indicating SSH proxy is ready to distribute data
#'
#' Field has to be `proxy`
SSH_READY = 21L

#' Message telling the SSH proxy to clean up
#'
#' No fields. Signals the worker to break its main loop.
SSH_STOP = 22L

#' SSH proxy heartbeating
#'
#' No fields. Answer has to be `SSH_NOOP`
SSH_NOOP = 23L

#' Message is an SSH command
#'
#' Field is either `exec` (command to run) or `reply` (how it went)
SSH_CMD = -24L

#' Chunk of iterated arguments for the worker
#'
#' Field has to be `chunk`
DO_CHUNK = 30L
