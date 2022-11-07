loadModule("cmq_master", TRUE) # CMQWorker C++ class
loadModule("cmq_worker", TRUE) # CMQWorker C++ class

do_work = function() {
    devtools::load_all(".")

    ctx = zmq_context() # inproc:// needs same context

    m = methods::new(CMQMaster, ctx)
    addr = m$listen("inproc://endpoint")
    m$add_env("x", 3)

    w = methods::new(CMQWorker, ctx)
    w$connect("inproc://endpoint")

    m$recv(-1L)
    m$send(expression(5 + x))
    w$process_one()

    m$recv(-1L)
    # create call, send via master
    # recv on worker, exec
    # send back to master and recv

    w$close()
    m$close()
    ctx_close(ctx)
}
