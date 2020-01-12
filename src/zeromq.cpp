#include <Rcpp.h>
#include <chrono>
#include <string>
#include "zmq.hpp"

typedef std::chrono::high_resolution_clock Time;
typedef std::chrono::milliseconds ms;
extern Rcpp::Function R_serialize;
extern Rcpp::Function R_unserialize;
extern int pending_interrupt();

class ZeroMQ {
public:
    ZeroMQ(int threads=1) { ctx = new zmq::context_t(threads); }
    ~ZeroMQ() {
        disconnect();
        delete ctx;
    }

    void listen(std::string socket_type, std::string address) {
        sock = new zmq::socket_t(*ctx, str2socket(socket_type));
        sock->bind(address);
        addr = address;
    }
    void connect(std::string socket_type, std::string address) {
        sock = new zmq::socket_t(*ctx, str2socket(socket_type));
        sock->connect(address);
        addr = address;
    }
    void disconnect() {
        if (sock) {
            delete sock;
            sock = NULL;
        }
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
        sock->send(message, flags);
    }
    SEXP receive(bool dont_wait=false, bool unserialize=true) {
        auto message = rcv_msg(dont_wait);
        SEXP ans = Rf_allocVector(RAWSXP, message.size());
        memcpy(RAW(ans), message.data(), message.size());
        if (unserialize)
            return R_unserialize(ans);
        else
            return ans;
    }
    SEXP poll(int timeout=-1) {
        auto nsock = 1;

        auto pitems = std::vector<zmq::pollitem_t>(nsock);
        for (int i = 0; i < nsock; i++) {
            pitems[i].socket = *sock; // only one socket for now
            pitems[i].events = ZMQ_POLLIN; // | ZMQ_POLLOUT; ssh_proxy XREP/XREQ has 2200
        }

        int rc = -1;
        auto start = Time::now();
        do {
            try {
                rc = zmq::poll(pitems, timeout);
            } catch(zmq::error_t &e) {
                if (errno != EINTR || pending_interrupt())
                    throw e;
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
    std::string addr;
    zmq::context_t *ctx;
    zmq::socket_t *sock;

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

    zmq::message_t rcv_msg(bool dont_wait=false) {
        auto flags = zmq::recv_flags::none;
        if (dont_wait)
            flags = flags | zmq::recv_flags::dontwait;

        zmq::message_t message;
        sock->recv(message, flags);
        return message;
    }
};

RCPP_MODULE(zmq) {
    using namespace Rcpp;
    class_<ZeroMQ>("ZeroMQ_raw")
        .constructor() // .constructor<int>() SIGABRT
        .method("listen", &ZeroMQ::listen)
        .method("connect", &ZeroMQ::connect)
        .method("disconnect", &ZeroMQ::connect)
        .method("send", &ZeroMQ::send)
        .method("receive", &ZeroMQ::receive)
        .method("poll", &ZeroMQ::poll)
    ;
}
