#ifndef _ZEROMQ_HPP_
#define _ZEROMQ_HPP_

#include <Rcpp.h>
#include <chrono>
#include <string>
#include <thread>
#include <unordered_map>
#include "zmq.hpp"
#include "MonitoredSocket.hpp"

typedef std::chrono::high_resolution_clock Time;
typedef std::chrono::milliseconds ms;
int pending_interrupt();

class ZeroMQ {
public:
    ZeroMQ(zmq::context_t * ctx_) : ctx(ctx_), sockets() {}
    ZeroMQ(int threads=1) : ctx(new zmq::context_t(threads)), sockets() {}
    ~ZeroMQ() {
        for (auto & it: sockets) {
            delete it.second;
        }
        ctx->close();
        delete ctx;
    }
    ZeroMQ(const ZeroMQ &) = delete;
    ZeroMQ & operator=(ZeroMQ const &) = delete;

    // convenience functions to quickly create and add sockets
    std::string listen(Rcpp::CharacterVector addrs, std::string socket_type="ZMQ_REP",
            std::string sid="default") {
        auto * ms = new MonitoredSocket(ctx, str2socket(socket_type), sid);
        auto bound_endpoint = ms->listen(addrs);
        sockets.emplace(sid, std::move(ms));
        return bound_endpoint;
    }
    void connect(std::string address, std::string socket_type="ZMQ_REQ", std::string sid="default") {
        auto * ms = new MonitoredSocket(ctx, str2socket(socket_type), sid);
        ms->sock.connect(address);
        sockets.emplace(sid, std::move(ms));
    }
    void disconnect(std::string sid="default") {
        auto * ms = find_socket(sid);
        delete ms;
        sockets.erase(sid);
    }
    void send(SEXP data, std::string sid="default", bool dont_wait=false, bool send_more=false) {
        auto * ms = find_socket(sid);
        ms->send(data, dont_wait, send_more);
    }
    void send_null(std::string sid="default", bool dont_wait=false, bool send_more=false) {
        auto * ms = find_socket(sid);
        ms->send_null(dont_wait, send_more);
    }
    SEXP receive(std::string sid="default", bool dont_wait=false, bool unserialize=true) {
        auto * ms = find_socket(sid);
        return ms->receive(dont_wait, unserialize);
    }
    bool rcv_more(std::string sid="default") {
        auto * ms = find_socket(sid);
        return ms->sock.get(zmq::sockopt::rcvmore);
    }

    void add_socket(MonitoredSocket * ms, std::string sid="default") {
        sockets.emplace(sid, std::move(ms));
    }

    Rcpp::IntegerVector poll(Rcpp::CharacterVector sids, int timeout=-1) {
        auto nsock = sids.length();
        auto pitems = std::vector<zmq::pollitem_t>(nsock*2);
        auto monsocks = std::vector<MonitoredSocket*>(nsock);
        for (int i = 0; i < nsock; i++) {
            monsocks[i] = find_socket(Rcpp::as<std::string>(sids[i]));
            pitems[i].socket = monsocks[i]->sock;
            pitems[i].events = ZMQ_POLLIN; // | ZMQ_POLLOUT; // ssh_proxy XREP/XREQ has 2200
            pitems[i+nsock].socket = monsocks[i]->mon;
            pitems[i+nsock].events = ZMQ_POLLIN;
        }

        auto start = Time::now();
        auto time_ms = std::chrono::milliseconds(timeout);
        int total_sock_ev = 0;
        auto result = Rcpp::IntegerVector(nsock);
        do {
            try {
                zmq::poll(pitems, time_ms);
            } catch(zmq::error_t const & e) {
                if (errno != EINTR || pending_interrupt())
                    Rf_error(e.what());
                if (timeout != -1) {
                    time_ms -= std::chrono::duration_cast<ms>(Time::now() - start);
                    if (time_ms.count() <= 0)
                        break;
                        break;
                }
            }

            //TODO: remove Rcpp from ZeroMQ class (SEXP -> void*, std::string overload?)
            for (int i = 0; i < nsock; i++) {
                result[i] = pitems[i].revents;
                total_sock_ev += pitems[i].revents;
                for (int j = 0; j < pitems[i+nsock].revents; j++)
                    monsocks[i]->handle_monitor_event();
            }
        } while(total_sock_ev == 0);

        return result;
    }

protected:
    zmq::context_t * ctx;
    std::unordered_map<std::string, MonitoredSocket*> sockets;

    int str2socket(std::string str) {
        if (str == "ZMQ_REP") {
            return ZMQ_REP;
        } else if (str == "ZMQ_REQ") {
            return ZMQ_REQ;
        } else if (str == "ZMQ_XREP") {
            return ZMQ_XREP;
        } else if (str == "ZMQ_XREQ") {
            return ZMQ_XREQ;
        } else {
            Rcpp::exception(("Invalid socket type: " + str).c_str());
        }
        return -1;
    }

    MonitoredSocket * find_socket(std::string socket_id) {
        auto socket_iter = sockets.find(socket_id);
        if (socket_iter == sockets.end())
            Rf_error("Trying to access non-existing socket: ", socket_id.c_str());
        return socket_iter->second;
    }
};

#endif // _ZEROMQ_HPP_
