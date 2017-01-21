#' Master controlling the workers
#'
#' exchanging messages between the master and workers works the following way:
#'  * we have submitted a job where we don't know when it will start up
#'  * it starts, sends is a message list(id=0) indicating it is ready
#'  * we send it the function definition and common data
#'    * we also send it the first data set to work on
#'  * when we get any id > 0, it is a result that we store
#'    * and send the next data set/index to work on
#'  * when computatons are complete, we send id=0 to the worker
#'    * it responds with id=-1 (and usage stats) and shuts down
#'
#' @param fun             A function to call
#' @param iter            Objects to be iterated in each function call
#' @param const           A list of constant arguments passed to each function call
#' @param seed            A seed to set for each function call
#' @param memory          The amount of Mb to request from LSF; default: 1 Gb
#' @param n_jobs          The number of LSF jobs to submit
#' @param fail_on_error   If an error occurs on the workers, continue or fail?
#' @param log_worker      Write a log file for each worker
#' @param wait_time       Time to wait between messages; set 0 for short calls
#'                        defaults to 1/sqrt(number_of_functon_calls)
#' @param chunk_size      Number of function calls to chunk together
#'                        defaults to 100 chunks per worker or max. 500 kb per chunk
#' @return                A list of whatever `fun` returned
master = function(fun, iter, const=list(), seed=128965, memory=4096, n_jobs=NULL,
        fail_on_error=TRUE, log_worker=FALSE, wait_time=NA, chunk_size=NA) {

    qsys = qsys$new(fun=fun, const=const, seed=seed)
    on.exit(qsys$cleanup(dirty=TRUE))
    n_calls = nrow(iter)

    # do the submissions
    message("Submitting ", n_jobs, " worker jobs for ", n_calls,
            " function calls (ID: ", qsys$id, ") ...")
    pb = utils::txtProgressBar(min=0, max=n_jobs, style=3)
    for (j in 1:n_jobs) {
        qsys$submit_job(memory=memory, log_worker=log_worker)
        utils::setTxtProgressBar(pb, j)
    }
    close(pb)

    # sync send/receive cycles with the ssh_proxy
    if (qsys_id == "ssh")
        qsys$send_job_data(id="SSH_NOOP")

    # prepare empty variables for managing results
    job_result = rep(list(NULL), n_calls)
    submit_index = 1:chunk_size
    jobs_running = list()
    workers_running = list()
    worker_stats = list()

    message("Running calculations (", chunk_size, " calls/chunk) ...")
    pb = utils::txtProgressBar(min=0, max=n_calls, style=3)

    # main event loop
    start_time = proc.time()
    while(submit_index[1] <= n_calls || length(workers_running) > 0) {
        msg = qsys$receive_data()

        if (msg$id == "SSH_NOOP") { # ssh heartbeating
            qsys$send_job_data(id="SSH_NOOP")
            next #TODO: can get rid of next if switching msg$id
        }

        if (msg$id == "WORKER_UP") { # worker ready, send common data
            qsys$send_common_data()
            workers_running[[msg$worker_id]] = TRUE
        } else if (msg$id == "WORKER_DONE") { # worker done, shutting down
            worker_stats[[msg$worker_id]] = msg$time
            workers_running[[msg$worker_id]] = NULL
            qsys$send_job_data() # close REQ/REP
            next
        } else if (msg$id == "DONE_CHUNK") { # worker sending result
            call_id = names(msg$result)
            jobs_running[call_id] = NULL
            job_result[as.integer(call_id)] = unname(msg$result)
            utils::setTxtProgressBar(pb, submit_index[1] - length(jobs_running) - 1)
        }

        # executed with any of above options
        if (submit_index[1] <= n_calls) { # send iterated data to worker
            submit_index = submit_index[submit_index <= n_calls]
            cur = iter[submit_index, , drop=FALSE]
            qsys$send_job_data(id="DO_CHUNK", chunk=cur)
            jobs_running[as.character(submit_index)] = TRUE
            submit_index = submit_index + chunk_size
        } else # send shutdown signal to worker
            qsys$send_job_data(id="WORKER_STOP")

        Sys.sleep(wait_time)
    }

    rt = proc.time() - start_time
    close(pb)

    qsys$cleanup(dirty=FALSE)
    on.exit(NULL)

    # check for failed jobs, report which and how many failed
    failed = which(sapply(job_result, class) == "try-error")
    if (any(failed)) {
        warning(lapply(failed, function(x) paste0("(#", x, ") ", job_result[[x]])))
        if (fail_on_error)
            stop(length(failed), "/", length(job_result), " jobs failed. Stopping.")
    }

    # compute summary statistics for workers
    wt = Reduce(`+`, worker_stats) / length(worker_stats)
    message(sprintf("Master: [%.1fs %.1f%% CPU]; Worker average: [%.1f%% CPU]",
                    rt[[3]], 100*(rt[[1]]+rt[[2]])/rt[[3]],
                    100*(wt[[1]]+wt[[2]])/wt[[3]]))

    job_result
}
