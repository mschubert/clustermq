#' R worker submitted as cluster job
#'
#' Do not call this manually, the master will do that
#'
#' @param worker_id  The ID of the worker (usually just numbered)
#' @param master     The master address (tcp://ip:port)
#' @param memlimit   Maximum memory before throwing an error
worker = function(worker_id, master, memlimit) {
    # https://github.com/krlmlr/ulimit, not on CRAN
    if (requireNamespace("ulimit", quietly=TRUE))
        ulimit::memory_limit(memlimit)

    print(master)
    print(memlimit)

    # connect to master
    context = rzmq::init.context()
    socket = rzmq::init.socket(context, "ZMQ_REQ")
    #rzmq::set.send.timeout(socket, 10000) # milliseconds

    # send the master a ready signal
    rzmq::connect.socket(socket, master)
    rzmq::send.socket(socket, data=list(id="WORKER_UP", worker_id=worker_id))

    # receive common data
    msg = rzmq::receive.socket(socket)
    fun = msg$fun
    const = msg$const
    seed = msg$seed

    print(fun)
    print(names(const))

    start_time = proc.time()
    counter = 0

    while(TRUE) {
        msg = rzmq::receive.socket(socket)
        message("received: ", msg$id)

        if (msg$id == "WORKER_STOP")
            break

        if (msg$id == "DO_CHUNK") {
            result = work_chunk(msg$chunk, fun, const, seed)
            message("completed: ", paste(rownames(msg$chunk), collapse=", "))
            names(result) = rownames(msg$chunk)
            rzmq::send.socket(socket, data=list(id="DONE_CHUNK", result=result))

            counter = counter + length(result)
            print(pryr::mem_used())
        }
    }

    run_time = proc.time() - start_time

    message("shutting down worker")
    data = list(id="WORKER_DONE", worker_id=worker_id, time=run_time, calls=counter)
    rzmq::send.socket(socket, data)

    print(run_time)
}
