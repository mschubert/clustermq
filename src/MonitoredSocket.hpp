#include <Rcpp.h> // Rf_error, replace by exception and catch upstream
#include "zmq.hpp"

class MonitoredSocket : public zmq::socket_t {
public:
    //TODO: add peer tracking of router socket
    MonitoredSocket(zmq::context_t &ctx, int socket_type, std::string sid):
            sock(ctx, socket_type), mon(ctx, ZMQ_PAIR) {
        auto mon_addr = "inproc://" + sid;
        int rc = zmq_socket_monitor(sock, mon_addr.c_str(), ZMQ_EVENT_DISCONNECTED);
        if (rc < 0) // C API needs return value check
            Rf_error("failed to create socket monitor");
        mon.connect(mon_addr);
    }

    zmq::socket_t sock;
    zmq::socket_t mon;
};
