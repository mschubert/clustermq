#include <Rcpp.h>
#include "MonitoredSocket.hpp"

class WorkerSocket : public MonitoredSocket {
    // override even monitor here, e.g. with peer tracking
};

class CMQWorker { // derive from ZeroMQ class? -> no, might have more than one socket
public:
    // speed-critical worker logic
    CMQWorker(std::string master): zmq(ZeroMQ()) {
        zmq.connect(master)
    }

private:
    ZeroMQ zmq;
};
