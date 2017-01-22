#' Message ID indicating worker is accepting jobs
WORKER_UP = -13L

#' Message ID indicating worker is accepting jobs
#'
#' It may optionally contain the field 'result' with a finished chunk
WORKER_READY = 0L

#' Message ID indicating worker is shutting down
WORKER_DONE = -1L

#' Message ID telling worker to stop
WORKER_STOP = 0L

#' Message ID indicating SSH proxy is up
SSH_UP = -5L

#' Message ID indicating SSH proxy is ready to distribute data
SSH_READY = -6L

#' Message telling the SSH proxy to clean up
SSH_STOP = -7L

#' SSH proxy heartbeating
SSH_NOOP = -9L

#' Message is an SSH command
#'
#' field is either exec (command to run) or reply (how it went)
SSH_CMD = -10L

#' Chunk of iterated arguments for the worker (fields: chunk)
DO_CHUNK = -12L
