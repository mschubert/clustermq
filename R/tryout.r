loadModule("cmq_master", TRUE) # CMQWorker C++ class
loadModule("cmq_worker", TRUE) # CMQWorker C++ class

do_work = function() {
    m = methods::new(CMQMaster)
    addr = m$listen("tcp://*:9998")
    m$add_env("x", 3)

    w = methods::new(CMQWorker, "tcp://127.0.0.1:9998")
    w$send("wtest")

    m$recv_one(-1L)
    m$send_one(quote({ 5 + x }))
    w$process_one()

    m$recv_one(-1L)
    # create call, send via master
    # recv on worker, exec
    # send back to master and recv
}
