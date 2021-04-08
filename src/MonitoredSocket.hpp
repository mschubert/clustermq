#ifndef _MONITORED_SOCKET_HPP_
#define _MONITORED_SOCKET_HPP_

#include <Rcpp.h> // Rf_error, replace by exception and catch upstream
#include "zmq.hpp"

extern Rcpp::Function R_serialize;
extern Rcpp::Function R_unserialize;

class MonitoredSocket {
public:
    //TODO: add peer tracking of router socket
//    MonitoredSocket() = delete;
    MonitoredSocket(zmq::context_t * ctx, int socket_type, std::string sid):
            sock(*ctx, socket_type), mon(*ctx, ZMQ_PAIR) {
        auto mon_addr = "inproc://" + sid;
        int rc = zmq_socket_monitor(sock, mon_addr.c_str(), ZMQ_EVENT_DISCONNECTED);
        if (rc < 0) // C API needs return value check
            Rf_error("failed to create socket monitor");
        mon.connect(mon_addr);
    }
//    MonitoredSocket(const MonitoredSocket &) = delete;
    virtual ~MonitoredSocket() {
        int linger = 0;
        sock.setsockopt(ZMQ_LINGER, &linger, sizeof(linger));
        std::cerr << "closing socket... " << std::flush;
        sock.close();
        std::cerr << "closing monitor\n" << std::flush;
        mon.close();
    }

    zmq::socket_t sock;
    zmq::socket_t mon;

    std::string listen(Rcpp::CharacterVector addrs) {
        int i;
        for (i=0; i<addrs.length(); i++) {
            auto addr = Rcpp::as<std::string>(addrs[i]);
            try {
                sock.bind(addr);
            } catch(zmq::error_t const &e) {
                if (errno != EADDRINUSE)
                    Rf_error(e.what());
            }
            char option_value[1024];
            size_t option_value_len = sizeof(option_value);
            sock.getsockopt(ZMQ_LAST_ENDPOINT, option_value, &option_value_len);
            return std::string(option_value);
        }
        Rf_error("Could not bind port after ", i, " tries");
    }
    inline void connect(std::string address) {
        sock.connect(address);
    }

    void send(SEXP data, bool dont_wait=false, bool send_more=false) {
        auto flags = zmq::send_flags::none;
        if (dont_wait)
            flags = flags | zmq::send_flags::dontwait;
        if (send_more)
            flags = flags | zmq::send_flags::sndmore;

        if (TYPEOF(data) != RAWSXP)
            data = R_serialize(data, R_NilValue);

        zmq::message_t message(Rf_xlength(data));
        memcpy(message.data(), RAW(data), Rf_xlength(data));
        sock.send(message, flags);
    }
    SEXP receive(bool dont_wait=false, bool unserialize=true) {
        auto flags = zmq::recv_flags::none;
        if (dont_wait)
            flags = flags | zmq::recv_flags::dontwait;

        zmq::message_t message;
        sock.recv(message, flags);
        SEXP ans = Rf_allocVector(RAWSXP, message.size());
        memcpy(RAW(ans), message.data(), message.size());
        if (unserialize)
            return R_unserialize(ans);
        else
            return ans;
    }

    virtual void handle_monitor_event() {
        // deriving class overrides to actually handle
        zmq::message_t msg1, msg2;
        mon.recv(msg1, zmq::recv_flags::dontwait);
        mon.recv(msg2, zmq::recv_flags::dontwait);
        std::cerr << "base event received\n";
    }
};

#endif // _MONITORED_SOCKET_HPP_
