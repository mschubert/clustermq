#include <Rcpp.h>
#include "MonitoredSocket.hpp"
#include "zeromq.hpp"

class WorkerSocket : public MonitoredSocket {
public:
    WorkerSocket(zmq::context_t & ctx, std::string addr):
            MonitoredSocket(ctx, ZMQ_REQ, "remove_sid_here") {
        connect(addr);
    }
    ~WorkerSocket() {
    }

private:
};

class CMQWorker : public ZeroMQ {
public:
    // speed-critical worker logic
//    CMQWorker(std::string master): zmq(ZeroMQ()) {
//        zmq.connect(master)
//    }

private:
//    ZeroMQ zmq;
};
