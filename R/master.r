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
#' @param export          List of objects to be exported to the worker
#' @param seed            A seed to set for each function call
#' @param template  Named list of values to fill in template
#' @param walltime        The amount of time a job has to complete; default: no value
#' @param n_jobs          The number of LSF jobs to submit
#' @param fail_on_error   If an error occurs on the workers, continue or fail?
#' @param log_worker      Write a log file for each worker
#' @param wait_time       Time to wait between messages; set 0 for short calls
#'                        defaults to 1/sqrt(number_of_functon_calls)
#' @param chunk_size      Number of function calls to chunk together
#'                        defaults to 100 chunks per worker or max. 500 kb per chunk
#' @return                A list of whatever `fun` returned
master = function(fun, iter, const=list(), export=list(), seed=128965,
        template=list(), n_jobs=NULL, walltime=NA,
        fail_on_error=TRUE, log_worker=FALSE, wait_time=NA, chunk_size=NA) {

    qsys = qsys$new(data=list(fun=fun, const=const, export=export, seed=seed))
    on.exit(qsys$cleanup(dirty=TRUE))
    n_calls = nrow(iter)

    # do the submissions
    message("Submitting ", n_jobs, " worker jobs for ",
            format(n_calls, big.mark=",", scientific=FALSE),
            " function calls (ID: ", qsys$id, ") ...")
    pb = utils::txtProgressBar(min=0, max=n_jobs, style=3)
    for (j in 1:n_jobs) {
        qsys$submit_job(template=template, log_worker=log_worker)
        utils::setTxtProgressBar(pb, j)
    }
    close(pb)

    # prepare empty variables for managing results
    job_result = rep(list(NULL), n_calls)
    submit_index = 1:chunk_size
    jobs_running = list()
    workers_running = list()
    worker_stats = list()
    warnings = list()
    shutdown = FALSE

    message("Running calculations (", chunk_size, " calls/chunk) ...")
    pb = utils::txtProgressBar(min=0, max=n_calls, style=3)

    # main event loop
    start_time = proc.time()
    while((!shutdown && submit_index[1] <= n_calls) || length(workers_running) > 0) {
        # wait for results only longer if we don't have all data yet
        if ((!shutdown && submit_index[1] <= n_calls) || length(jobs_running) > 0)
            msg = qsys$receive_data()
        else {
            msg = qsys$receive_data(timeout=5)
            if (is.null(msg)) {
                warning(sprintf("%i/%i workers did not shut down properly",
                        length(workers_running), n_jobs), immediate.=TRUE)
                break
            }
        }

        switch(msg$id,
            "WORKER_UP" = {
                workers_running[[msg$worker_id]] = TRUE
                qsys$send_common_data()
            },
            "WORKER_READY" = {
                # process the result data if we got some
                if (!is.null(msg$result)) {
                    call_id = names(msg$result)
                    jobs_running[call_id] = NULL
                    job_result[as.integer(call_id)] = unname(msg$result)
                    utils::setTxtProgressBar(pb, submit_index[1] -
                                             length(jobs_running) - 1)

                    errors = sapply(msg$result, class) == "error"
                    if (any(errors) && fail_on_error == TRUE)
                        shutdown = TRUE
                    warnings = c(warnings, msg$warnings)
                }

                # if we have work, send it to the worker
                if (!shutdown && submit_index[1] <= n_calls) {
                    submit_index = submit_index[submit_index <= n_calls]
                    cur = iter[submit_index, , drop=FALSE]
                    qsys$send_job_data(id="DO_CHUNK", chunk=cur)
                    jobs_running[as.character(submit_index)] = TRUE
                    submit_index = submit_index + chunk_size
                } else # or else shut it down
                    qsys$send_job_data(id="WORKER_STOP")
            },
            "WORKER_DONE" = {
                worker_stats[[msg$worker_id]] = msg
                workers_running[[msg$worker_id]] = NULL
                qsys$send_job_data() # close REQ/REP
            }
        )

        Sys.sleep(wait_time)
    }

    rt = proc.time() - start_time
    close(pb)

    qsys$cleanup(dirty=FALSE)
    on.exit(NULL)

    result = unravel_result(list(result=job_result, warnings=warnings),
                            at = min(submit_index)-1,
                            fail_on_error = fail_on_error)

    # compute summary statistics for workers
    times = lapply(worker_stats, function(w) w$time)
    wt = Reduce(`+`, times) / length(times)
    message(sprintf("Master: [%.1fs %.1f%% CPU]; Worker average: [%.1f%% CPU]",
                    rt[[3]], 100*(rt[[1]]+rt[[2]])/rt[[3]],
                    100*(wt[[1]]+wt[[2]])/wt[[3]]))

    result
}
