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
#' @useDynLib clustermq
#' @import Rcpp
NULL
