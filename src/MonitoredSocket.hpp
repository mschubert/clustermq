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
        int rc = zmq_socket_monitor(sock, mon_addr.c_str(), ZMQ_EVENT_ALL);
        if (rc < 0) // C API needs return value check
            Rf_error("failed to create socket monitor");
        mon.connect(mon_addr);
    }
//    MonitoredSocket(const MonitoredSocket &) = delete;
    virtual ~MonitoredSocket() {
        mon.set(zmq::sockopt::linger, 0);
        mon.close();
        sock.set(zmq::sockopt::linger, 0);
        sock.close();
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
            return sock.get(zmq::sockopt::last_endpoint);
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
    void send_null(bool dont_wait=false, bool send_more=false) {
        auto flags = zmq::send_flags::none;
        if (dont_wait)
            flags = flags | zmq::send_flags::dontwait;
        if (send_more)
            flags = flags | zmq::send_flags::sndmore;

        zmq::message_t message(0);
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
    }

protected:
    struct mon_ev {
        uint16_t event;
        std::string addr;
    };

    mon_ev recv_monitor_event() {
        zmq::message_t msg1, msg2;
        mon.recv(msg1, zmq::recv_flags::dontwait);
        mon.recv(msg2, zmq::recv_flags::dontwait);

        mon_ev ev;
        ev.event = *static_cast<uint16_t*>(msg1.data());
        ev.addr = msg2.to_string();
        return ev;
    }
};

#endif // _MONITORED_SOCKET_HPP_
