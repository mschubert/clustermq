#include <Rcpp.h>
#include <string>
#include "zmq.hpp"

// [[Rcpp::export]]
bool has_connectivity(std::string host) {
    bool success = false;
    zmq::context_t ctx;
    zmq::socket_t server = zmq::socket_t(ctx, ZMQ_REP);
    zmq::socket_t client = zmq::socket_t(ctx, ZMQ_REQ);

    try {
        server.bind("tcp://*:*");
        std::string addr = server.get(zmq::sockopt::last_endpoint);
        const std::string all_hosts = "0.0.0.0";
        addr.replace(addr.find(all_hosts), all_hosts.size(), host);

        client.connect(addr);
        const std::string msg1 = "testing connection";
        client.send(zmq::buffer(msg1), zmq::send_flags::none);

        zmq::message_t msg2;
        auto time_ms = std::chrono::milliseconds(200);
        auto pitems = std::vector<zmq::pollitem_t>(1);
        pitems[0].socket = server;
        pitems[0].events = ZMQ_POLLIN;
        zmq::poll(pitems, time_ms);
        auto n = server.recv(msg2, zmq::recv_flags::dontwait);
        auto msg2_s = std::string(reinterpret_cast<const char*>(msg2.data()), msg2.size());

        if (msg1 == msg2_s)
            success = true;
    } catch(zmq::error_t const &e) {
//        std::cerr << e.what() << "\n";
        success = false;
    }

    client.set(zmq::sockopt::linger, 0);
    client.close();
    server.set(zmq::sockopt::linger, 0);
    server.close();
    ctx.close();

    return success;
}

// [[Rcpp::export]]
bool libzmq_has_draft() {
    #ifdef ZMQ_BUILD_DRAFT_API
    return true;
    #else
    return false;
    #endif
}
