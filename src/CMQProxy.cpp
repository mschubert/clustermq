#include <Rcpp.h>
#include "ZeroMQ.hpp"

class CMQProxy {
public:
    CMQProxy(int ctl_port, int job_port): ctx(new zmq::context_t(1)) {
    }
    ~CMQProxy() {
    }
};
