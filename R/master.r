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
#' @param pool           Instance of Pool object
#' @param iter           Objects to be iterated in each function call
#' @param rettype        Return type of function
#' @param fail_on_error  If an error occurs on the workers, continue or fail?
#' @param chunk_size     Number of function calls to chunk together
#'                       defaults to 100 chunks per worker or max. 500 kb per chunk
#' @param timeout         Maximum time in seconds to wait for worker (default: Inf)
#' @param max_calls_worker  Maxmimum number of function calls that will be sent to one worker
#' @param verbose        Print progress messages
#' @return               A list of whatever `fun` returned
#' @keywords  internal
master = function(pool, iter, rettype="list", fail_on_error=TRUE,
                  chunk_size=NA, timeout=Inf, max_calls_worker=Inf, verbose=TRUE) {
    # prepare empty variables for managing results
    n_calls = nrow(iter)
    job_result = rep(vec_lookup[[rettype]], n_calls)
    submit_index = 1:chunk_size
    jobs_running = 0
    cond_msgs = list(warnings=list(), errors=list())
    n_errors = 0
    n_warnings = 0
    shutdown = FALSE
    kill_workers = FALSE
    penv = pool$env(work_chunk=work_chunk)
    obj_size = structure(sum(penv$size), class="object_size")
    obj_size_fmt = format(obj_size, big.mark=",", units="auto")
    if (is.infinite(timeout)) {
        timeout = -1L
    } else {
        timeout = timeout * 1000 # Rcpp API uses msec
    }

    #TODO: warn before serialization, create pool+env & then submit
    if (obj_size/1e6 > getOption("clustermq.data.warning", 500))
        warning("Common data is ", obj_size_fmt, ". Recommended limit is ",
                getOption("clustermq.data.warning", 500),
                " Mb (set by clustermq.data.warning option)", immediate.=TRUE)

    if (!pool$reusable)
        on.exit(pool$cleanup())

    if (verbose) {
        message("Running ", format(n_calls, big.mark=",", scientific=FALSE),
                " calculations (", nrow(penv), " objs/", obj_size_fmt,
                " common; ", chunk_size, " calls/chunk) ...")
        pb = progress::progress_bar$new(total = n_calls,
                format = "[:bar] :percent (:wup/:wtot wrk) eta: :eta")
        pb$tick(0, tokens=list(wtot=pool$workers_total, wup=pool$workers_running))
    }

    # main event loop
    while((!shutdown && submit_index[1] <= n_calls) || jobs_running > 0) {
        msg = pool$recv(timeout)
        if (inherits(msg, "worker_error"))
            stop("Worker Error: ", msg)

        if (verbose)
            pb$tick(length(msg$result),
                    tokens=list(wtot=pool$workers_total, wup=pool$workers_running))

        # process the result data if we got some
        if (!is.null(msg$result)) {
            call_id = names(msg$result)
            jobs_running = jobs_running - length(call_id)
            job_result[as.integer(call_id)] = msg$result

            n_warnings = n_warnings + length(msg$warnings)
            n_errors = n_errors + length(msg$errors)
            if (n_errors > 0 && fail_on_error == TRUE)
                shutdown = TRUE
            if (length(cond_msgs$warnings) < 50)
                cond_msgs$warnings = c(cond_msgs$warnings, msg$warnings)
            if (length(cond_msgs$errors) < 50)
                cond_msgs$errors = c(cond_msgs$errors, msg$errors)
        }

        if (shutdown || with(pool$info(), calls[current]) >= max_calls_worker) {
            pool$send_shutdown()
            next
        }

        if (submit_index[1] <= n_calls) {
            # if we have work, send it to the worker
            submit_index = submit_index[submit_index <= n_calls]
            pool$send(work_chunk(chunk, fun=fun, const=const, rettype=rettype,
                common_seed=common_seed), chunk=chunk(iter, submit_index))
            jobs_running = jobs_running + length(submit_index)
            submit_index = submit_index + chunk_size

            # adapt chunk size towards end of processing
            cs = ceiling((n_calls - submit_index[1]) / pool$workers_running)
            if (cs < chunk_size) {
                chunk_size = max(cs, 1)
                submit_index = submit_index[1:chunk_size]
            }

        } else if (pool$reusable) {
            pool$send_wait()
        } else { # or else shut it down
            pool$send_shutdown()
        }
    }

    summarize_result(job_result, n_errors, n_warnings, cond_msgs,
                     min(submit_index)-1, fail_on_error)
}
