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
#' @param qsys           Instance of QSys object
#' @param iter           Objects to be iterated in each function call
#' @param rettype        Return type of function
#' @param fail_on_error  If an error occurs on the workers, continue or fail?
#' @param wait_time      Time to wait between messages; set 0 for short calls
#'                       defaults to 1/sqrt(number_of_functon_calls)
#' @param chunk_size     Number of function calls to chunk together
#'                       defaults to 100 chunks per worker or max. 500 kb per chunk
#' @return               A list of whatever `fun` returned
master = function(qsys, iter, rettype="list", fail_on_error=TRUE,
                  wait_time=NA, chunk_size=NA) {
    # prepare empty variables for managing results
    n_calls = nrow(iter)
    job_result = rep(vec_lookup[[rettype]], n_calls)
    submit_index = 1:chunk_size
    jobs_running = 0
    cond_msgs = list()
    n_errors = 0
    n_warnings = 0
    shutdown = FALSE
    pkgver = utils::packageVersion("clustermq")
    pkg_warn = TRUE

    message("Running ", format(n_calls, big.mark=",", scientific=FALSE),
            " calculations (", chunk_size, " calls/chunk) ...")
    pb = utils::txtProgressBar(min=0, max=n_calls, style=3)

    # main event loop
    while((!shutdown && submit_index[1] <= n_calls) || qsys$workers_running > 0) {
        # wait for results only longer if we don't have all data yet
        if ((!shutdown && submit_index[1] <= n_calls) || jobs_running > 0)
            msg = qsys$receive_data()
        else {
            msg = qsys$receive_data(timeout=10)
            if (is.null(msg)) {
                warning(sprintf("%i/%i workers did not shut down properly",
                        qsys$workers_running, qsys$workers), immediate.=TRUE)
                break
            }
        }

        switch(msg$id,
            "WORKER_UP" = {
                if (msg$pkgver != pkgver && pkg_warn) {
                    warning("\nVersion mismatch: master has ", pkgver,
                            ", worker ", msg$pkgver, immediate.=TRUE)
                    pkg_warn = FALSE
                }
                qsys$send_common_data()
            },
            "WORKER_READY" = {
                # process the result data if we got some
                if (!is.null(msg$result)) {
                    call_id = names(msg$result)
                    jobs_running = jobs_running - length(call_id)
                    job_result[as.integer(call_id)] = msg$result
                    utils::setTxtProgressBar(pb, submit_index[1] - jobs_running - 1)

                    n_warnings = n_warnings + length(msg$warnings)
                    n_errors = n_errors + length(msg$errors)
                    if (n_errors > 0 && fail_on_error == TRUE)
                        shutdown = TRUE
                    new_msgs = c(msg$errors, msg$warnings)
                    if (length(new_msgs > 0) && length(cond_msgs) < 50)
                        cond_msgs = c(cond_msgs, new_msgs[order(names(new_msgs))])
                }

                if (!shutdown && msg$token != qsys$data_token) {
                    qsys$send_common_data()

                } else if (!shutdown && submit_index[1] <= n_calls) {
                    # if we have work, send it to the worker
                    submit_index = submit_index[submit_index <= n_calls]
                    qsys$send_job_data(chunk = chunk(iter, submit_index))
                    jobs_running = jobs_running + length(submit_index)
                    submit_index = submit_index + chunk_size

                    # adapt chunk size towards end of processing
                    cs = ceiling((n_calls - submit_index[1]) / qsys$workers_running)
                    if (cs < chunk_size) {
                        chunk_size = max(cs, 1)
                        submit_index = submit_index[1:chunk_size]
                    }

                } else if (!shutdown && qsys$reusable) {
                    qsys$send_wait()
                    if (jobs_running == 0)
                        break

                } else # or else shut it down
                    qsys$send_shutdown_worker()
            },
            "WORKER_DONE" = {
                qsys$disconnect_worker(msg)
            },
            "WORKER_ERROR" = {
                stop("\nWorker error: ", msg$msg)
            }
        )

        Sys.sleep(wait_time)
    }

    close(pb)

    summarize_result(job_result, n_errors, n_warnings, cond_msgs,
                     min(submit_index)-1, fail_on_error)
}
