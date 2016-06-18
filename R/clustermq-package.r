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
