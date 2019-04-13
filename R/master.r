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
#' @param chunk_size     Number of function calls to chunk together
#'                       defaults to 100 chunks per worker or max. 500 kb per chunk
#' @param timeout         Maximum time in seconds to wait for worker (default: Inf)
#' @param max_calls_worker  Maxmimum number of function calls that will be sent to one worker
#' @return               A list of whatever `fun` returned
#' @keywords  internal
master = function(qsys, iter, rettype="list", fail_on_error=TRUE,
                  chunk_size=NA, timeout=Inf, max_calls_worker=Inf) {
    # prepare empty variables for managing results
    n_calls = nrow(iter)
    job_result = rep(vec_lookup[[rettype]], n_calls)
    submit_index = 1:chunk_size
    jobs_running = 0
    cond_msgs = list()
    n_errors = 0
    n_warnings = 0
    shutdown = FALSE
    kill_workers = FALSE

    on.exit(qsys$finalize())

    message("Running ", format(n_calls, big.mark=",", scientific=FALSE),
            " calculations (", qsys$data_num, " objs/",
            format(qsys$data_size, big.mark=",", units="Mb"),
            " common; ", chunk_size, " calls/chunk) ...")
    pb = progress::progress_bar$new(total = n_calls,
            format = "[:bar] :percent (:wup/:wtot wrk) eta: :eta")
    pb$tick(0)

    # main event loop
    while((!shutdown && submit_index[1] <= n_calls) || jobs_running > 0) {
        msg = qsys$receive_data(timeout=timeout)
        if (is.null(msg)) { # timeout reached
            if (shutdown) {
                kill_workers = TRUE
                break
            } else
                stop("Socket timeout reached, likely due to a worker crash")
        }

        pb$tick(length(msg$result),
                tokens=list(wtot=qsys$workers, wup=qsys$workers_running))

        # process the result data if we got some
        if (!is.null(msg$result)) {
            call_id = names(msg$result)
            jobs_running = jobs_running - length(call_id)
            job_result[as.integer(call_id)] = msg$result

            n_warnings = n_warnings + length(msg$warnings)
            n_errors = n_errors + length(msg$errors)
            if (n_errors > 0 && fail_on_error == TRUE) {
                shutdown = TRUE
                timeout = getOption("clustermq.error.timeout", min(timeout, 30))
            }
            new_msgs = c(msg$errors, msg$warnings)
            if (length(new_msgs) > 0 && length(cond_msgs) < 50)
                cond_msgs = c(cond_msgs, new_msgs[order(names(new_msgs))])
        }

        if (shutdown || (!is.null(msg$n_calls) && msg$n_calls >= max_calls_worker)) {
            qsys$send_shutdown_worker()
            next
        }

        if (msg$token != qsys$data_token) {
            qsys$send_common_data()

        } else if (submit_index[1] <= n_calls) {
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

        } else if (qsys$reusable) {
            qsys$send_wait()
        } else { # or else shut it down
            qsys$send_shutdown_worker()
        }
    }

    if (!kill_workers && (qsys$reusable || qsys$cleanup()))
        on.exit(NULL)

    summarize_result(job_result, n_errors, n_warnings, cond_msgs,
                     min(submit_index)-1, fail_on_error)
}
