#' Message ID indicating worker is accepting jobs
WORKER_UP = -13L

#' Message ID indicating worker is accepting jobs
WORKER_READY = 0L

#' Message ID indicating worker is shutting down
WORKER_DONE = -1L

#' Message ID indicating worker is requesting data
REQ_DATA = -2L

#' Message ID telling worker to stop
WORKER_STOP = 0L

##' Message ID to sync send/receive cycle (ignored by proxy)
#SSH_INIT = -8L # replaced by SSH_NOOP

#' Message ID indicating SSH proxy is up
SSH_UP = -5L

#' Message ID indicating SSH proxy is ready to distribute data
SSH_READY = -6L

#' Message telling the SSH proxy to clean up
SSH_STOP = -7L

#' SSH proxy heartbeating
SSH_NOOP = -9L

#' Message is an SSH command
SSH_CMD = -10L

#' Message is answer of try(command)
SSH_EXEC = -11L

#' Chunk of iterated arguments for the worker (fields: chunk)
DO_CHUNK = -12L

##' Worker results for a chunk (fields: result)
#DONE_CHUNK = -13L # replaced by WORKER_READY (result is optional in msg)
