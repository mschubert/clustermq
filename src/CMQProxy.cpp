#include <Rcpp.h>
#include "ZeroMQ.hpp"

class CMQProxy {
public:
    CMQProxy(std::string master_ctl, std::string master_data): ctx(new zmq::context_t(1)) {
        fwd_to_master = zmq::socket_t(*ctx, ZMQ_REQ);
        fwd_to_master.set(zmq::sockopt::connect_timeout, 10000);
        fwd_to_master.connect(master_data);

        fwd_to_worker = zmq::socket_t(*ctx, ZMQ_REP);
//        net_fwd = fwd_to_worker.listen();

//        master = CMQMaster(ctx);
    }
    ~CMQProxy() {
        fwd_to_master.set(zmq::sockopt::linger, 0);
        fwd_to_master.close();
        fwd_to_worker.set(zmq::sockopt::linger, 0);
        fwd_to_worker.close();

        data.set(zmq::sockopt::linger, 0);
        data.close();
        ctl.set(zmq::sockopt::linger, 0);
        ctl.close();

        ctx->close();
        delete ctx;
    }

private:
//    CMQMaster master; // needs to be included
    zmq::context_t *ctx;
    zmq::socket_t ctl;
    zmq::socket_t data;
    zmq::socket_t fwd_to_master;
    zmq::socket_t fwd_to_worker;

    std::string net_fwd;
};
