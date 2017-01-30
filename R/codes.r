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
