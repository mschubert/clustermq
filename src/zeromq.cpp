#include <Rcpp.h>
#include <chrono>
#include <string>
#include <unordered_map>
#include "zmq.hpp"

typedef std::chrono::high_resolution_clock Time;
typedef std::chrono::milliseconds ms;
extern Rcpp::Function R_serialize;
extern Rcpp::Function R_unserialize;
int pending_interrupt();

class ZeroMQ {
public:
    ZeroMQ(int threads=1) : ctx(threads), sockets() {}
    ZeroMQ(const ZeroMQ &) = delete;
    ZeroMQ & operator=(ZeroMQ const &) = delete;

    std::string listen(Rcpp::CharacterVector addrs, std::string socket_type="ZMQ_REP",
            std::string sid="default") {
        auto sock = zmq::socket_t(ctx, str2socket(socket_type));
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
            sockets.emplace(sid, std::move(sock));
            return std::string(option_value);
        }
        Rf_error("Could not bind port after ", i, " tries");
    }
    void connect(std::string address, std::string socket_type="ZMQ_REQ", std::string sid="default") {
        auto sock = zmq::socket_t(ctx, str2socket(socket_type));
        sock.connect(address);
        sockets.emplace(sid, std::move(sock));
    }
    void disconnect(std::string sid="default") {
        sockets.erase(sid);
    }

    void send(SEXP data, std::string sid="default", bool dont_wait=false, bool send_more=false) {
        auto & socket = find_socket(sid);
        auto flags = zmq::send_flags::none;
        if (dont_wait)
            flags = flags | zmq::send_flags::dontwait;
        if (send_more)
            flags = flags | zmq::send_flags::sndmore;

        if (TYPEOF(data) != RAWSXP)
            data = R_serialize(data, R_NilValue);

        zmq::message_t message(Rf_xlength(data));
        memcpy(message.data(), RAW(data), Rf_xlength(data));
        socket.send(message, flags);
    }
    SEXP receive(std::string sid="default", bool dont_wait=false, bool unserialize=true) {
        auto message = rcv_msg(sid, dont_wait);
        SEXP ans = Rf_allocVector(RAWSXP, message.size());
        memcpy(RAW(ans), message.data(), message.size());
        if (unserialize)
            return R_unserialize(ans);
        else
            return ans;
    }
    Rcpp::IntegerVector poll(Rcpp::CharacterVector sids, int timeout=-1) {
        auto nsock = sids.length();
        auto pitems = std::vector<zmq::pollitem_t>(nsock);
        for (int i = 0; i < nsock; i++) {
            auto socket_id = Rcpp::as<std::string>(sids[i]);
            pitems[i].socket = find_socket(socket_id);
            pitems[i].events = ZMQ_POLLIN; // | ZMQ_POLLOUT; // ssh_proxy XREP/XREQ has 2200
        }

        int rc = -1;
        auto start = Time::now();
        do {
            try {
                rc = zmq::poll(pitems, timeout);
            } catch(zmq::error_t const &e) {
                if (errno != EINTR || pending_interrupt())
                    Rf_error(e.what());
                if (timeout != -1) {
                    ms dt = std::chrono::duration_cast<ms>(Time::now() - start);
                    timeout = timeout - dt.count();
                    if (timeout <= 0)
                        break;
                }
            }
        } while(rc < 0);

        auto result = Rcpp::IntegerVector(nsock);
        for (int i = 0; i < nsock; i++)
            result[i] = pitems[i].revents;
        return result;
    }

private:
    zmq::context_t ctx;
    std::unordered_map<std::string, zmq::socket_t> sockets;

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

    zmq::socket_t & find_socket(std::string socket_id) {
        auto socket_iter = sockets.find(socket_id);
        if (socket_iter == sockets.end())
            Rf_error("Trying to access non-existing socket: ", socket_id.c_str());
        return socket_iter->second;
    }

    zmq::message_t rcv_msg(std::string sid="default", bool dont_wait=false) {
        auto flags = zmq::recv_flags::none;
        if (dont_wait)
            flags = flags | zmq::recv_flags::dontwait;

        zmq::message_t message;
        auto & socket = find_socket(sid);
        socket.recv(message, flags);
        return message;
    }
};

RCPP_MODULE(zmq) {
    using namespace Rcpp;
    class_<ZeroMQ>("ZeroMQ_raw")
        .constructor() // .constructor<int>() SIGABRT
        .method("listen", &ZeroMQ::listen)
        .method("connect", &ZeroMQ::connect)
        .method("disconnect", &ZeroMQ::disconnect)
        .method("send", &ZeroMQ::send)
        .method("receive", &ZeroMQ::receive)
        .method("poll", &ZeroMQ::poll)
    ;
}
