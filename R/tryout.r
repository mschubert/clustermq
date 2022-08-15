loadModule("cmq_master", TRUE) # CMQWorker C++ class
loadModule("cmq_worker", TRUE) # CMQWorker C++ class

do_work = function() {
    m = methods::new(CMQMaster)
    addr = m$listen("tcp://*:9998")

    w = methods::new(CMQWorker, "tcp://127.0.0.1:9998")
    w$send("wtest")

    m$poll_recv(-1L)
    m$send_work(quote({ 5 * 2 }))
    w$process_one()

    m$poll_recv(-1L)
    # create call, send via master
    # recv on worker, exec
    # send back to master and recv
}
