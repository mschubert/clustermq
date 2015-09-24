# this should be submitted by bsub
# and get the server as argument

master = commandArgs(TRUE)[1]
memlimit = as.integer(commandArgs(TRUE)[2])
ulimit::memory_limit(memlimit)
print(master)
print(memlimit)

library(rzmq)
context = init.context()
socket = init.socket(context, "ZMQ_REQ")
connect.socket(socket, master)
send.socket(socket, data=list(id=0))
msg = receive.socket(socket)
fun = msg$fun
const = msg$const

print(fun)
print(names(const))

while(TRUE) {
    msg = receive.socket(socket)
    if (msg$id == 0)
        break

    result = try(do.call(fun, c(const, msg$iter)))

    send.socket(socket, data=list(id = msg$id, result=result))

    print(pryr::mem_used())
}