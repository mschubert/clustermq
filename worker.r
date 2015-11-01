# this should be submitted by bsub
# and get the server as argument

master = commandArgs(TRUE)[1]
memlimit = as.integer(commandArgs(TRUE)[2])
ulimit::memory_limit(memlimit)
print(master)
print(memlimit)
has_pryr = requireNamespace("pryr", quietly=TRUE)

library(rzmq)
context = init.context()
socket = init.socket(context, "ZMQ_REQ")
connect.socket(socket, master)
send.socket(socket, data=list(id=0))
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
    if (msg$id == 0)
        break

    counter = counter + 1
    set.seed(seed + msg$id)
    result = try(do.call(fun, c(const, msg$iter)))

    send.socket(socket, data=list(id = msg$id, result=result))

    if (has_pryr)
        print(pryr::mem_used())
}

run_time = proc.time() - start_time

send.socket(socket, data=list(id=-1, time=run_time, calls=counter))

print(run_time)
