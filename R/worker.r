#' R worker submitted as cluster job
#'
#' Do not call this manually, the master will do that
#'
#' @param worker_id  The ID of the worker (usually just numbered)
#' @param master     The master address (tcp://ip:port)
#' @param memlimit   Maximum memory before throwing an error
run_worker = function(worker_id, master, memlimit) {
#    worker_id = commandArgs(TRUE)[1]
#    master = commandArgs(TRUE)[2]
#    memlimit = as.integer(commandArgs(TRUE)[3])
    ulimit::memory_limit(memlimit)
    print(master)
    print(memlimit)
    has_pryr = requireNamespace("pryr", quietly=TRUE)

    library(rzmq)
    context = init.context()
    socket = init.socket(context, "ZMQ_REQ")
    connect.socket(socket, master)
    send.socket(socket, data=list(id=0, worker_id=worker_id))
    msg = receive.socket(socket)
    fun = msg$fun
    const = msg$const
    seed = msg$seed

    print(fun)
    print(names(const))

    start_time = proc.time()
    counter = 0

    while(TRUE) {
        msg = receive.socket(socket)
        if (identical(msg$id, 0))
            break

        one_id = function(seq_num) {
            set.seed(seed + msg$id[seq_num])
            result = try(do.call(fun, c(const, msg$iter[[seq_num]])))
        }
        result = lapply(seq_along(msg$id), one_id)
        counter = counter + length(msg$id)

        send.socket(socket, data=list(id = msg$id, result=result))

        if (has_pryr)
            print(pryr::mem_used())
    }

    run_time = proc.time() - start_time

    send.socket(socket, data=list(id=-1, worker_id=worker_id, time=run_time, calls=counter))

    print(run_time)
}
