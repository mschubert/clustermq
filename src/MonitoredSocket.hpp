#include <Rcpp.h> // Rf_error, replace by exception and catch upstream
#include "zmq.hpp"

class MonitoredSocket {
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

//private:
    void handle_monitor_event() {
        // receive message to clear, but we know it is disconnect
        // expand this if we monitor anything else
        zmq::message_t msg1, msg2;
        // we expect 2 frames: http://api.zeromq.org/4-1:zmq-socket-monitor
        mon.recv(msg1, zmq::recv_flags::dontwait);
        mon.recv(msg2, zmq::recv_flags::dontwait);
        // do something with the info...

        Rf_error("unexpected peer disconnect"); // this is the only thing we monitor for now
    }
};
