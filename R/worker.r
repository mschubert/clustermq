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
    rzmq::connect.socket(socket, master)
    rzmq::send.socket(socket, data=list(id=0, worker_id=worker_id))

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
        if (identical(msg$id, 0))
            break

        one_id = function(seq_num) {
            set.seed(seed + msg$id[seq_num])
            result = try(do.call(fun, c(const, msg$iter[seq_num,])))
        }
        result = lapply(seq_along(msg$id), one_id)
        counter = counter + length(msg$id)

        rzmq::send.socket(socket, data=list(id = msg$id, result=result))

        print(pryr::mem_used())
    }

    run_time = proc.time() - start_time

    data = list(id=-1, worker_id=worker_id, time=run_time, calls=counter)
    rzmq::send.socket(socket, data)

    print(run_time)
}
