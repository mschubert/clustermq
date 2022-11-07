#include <Rcpp.h>
#include "ZeroMQ.h"

class CMQWorker { // : public ZeroMQ {
public:
    CMQWorker(): ctx(new zmq::context_t(1)) {
        external_context = false;
    }
    CMQWorker(SEXP ctx_): ctx(Rcpp::as<Rcpp::XPtr<zmq::context_t>>(ctx_)) {}
    ~CMQWorker() { close(); }

    void connect(std::string addr) {
        sock = zmq::socket_t(*ctx, ZMQ_REQ);
        if (zmq_socket_monitor(sock, "inproc://monitor", ZMQ_EVENT_DISCONNECTED) < 0)
            Rf_error("failed to create socket monitor");
        mon = zmq::socket_t(*ctx, ZMQ_PAIR);
        mon.connect("inproc://monitor");

        sock.set(zmq::sockopt::connect_timeout, 10000);
        sock.connect(addr);
        sock.send(r2msg(R_NilValue), zmq::send_flags::none);
    }
    void close() {
        if (mon.handle() != nullptr) {
            mon.set(zmq::sockopt::linger, 0);
            mon.close();
        }
        if (sock.handle() != nullptr) {
            sock.set(zmq::sockopt::linger, 10000);
            sock.close();
        }
        if (!external_context) {
            ctx->close();
            delete ctx;
            ctx = nullptr;
        }
    }
//todo: separate close func? (+ make sure 2nd close is no-op)
//todo: start writing tests for eval w/ inproc

    bool process_one() {
        std::vector<zmq::message_t> msgs;
        recv_multipart(sock, std::back_inserter(msgs));
        auto status = *static_cast<wlife_t*>(msgs[0].data());
        auto cmd = msg2r(msgs[1]);

        for (auto it=msgs.begin()+2; it<msgs.end(); it++) {
            Rcpp::List obj = msg2r(*it);
            env.assign(obj.names(), obj[0]);
            if (Rcpp::as<std::string>(obj.names()).compare(0, 8, "package:") == 0)
                load_pkg(obj[0]);
        }

        SEXP eval = Rcpp::Rcpp_eval(cmd, env);
        sock.send(r2msg(eval), zmq::send_flags::none);
        return status == wlife_t::active;
    }

private:
    bool external_context {true};
    zmq::context_t *ctx;
    zmq::socket_t sock;
    zmq::socket_t mon;
    Rcpp::Environment env {1};
    Rcpp::Function load_pkg {"library"};

    zmq::message_t str2msg(std::string str) {
        zmq::message_t msg(str.length());
        memcpy(msg.data(), str.data(), str.length());
        return msg;
    }
    zmq::message_t r2msg(SEXP data) {
        if (TYPEOF(data) != RAWSXP)
            data = R_serialize(data, R_NilValue);
        zmq::message_t msg(Rf_xlength(data));
        memcpy(msg.data(), RAW(data), Rf_xlength(data));
        return msg;
    }
    SEXP msg2r(zmq::message_t &msg, bool unserialize=true) {
        SEXP ans = Rf_allocVector(RAWSXP, msg.size());
        memcpy(RAW(ans), msg.data(), msg.size());
        if (unserialize)
            return R_unserialize(ans);
        else
            return ans;
    }

    void poll() {
        auto pitems = std::vector<zmq::pollitem_t>(2);
        pitems[0].socket = sock;
        pitems[0].events = ZMQ_POLLIN;
        pitems[1].socket = mon;
        pitems[1].events = ZMQ_POLLIN;

        int total_sock_ev = 0;
        do {
            try {
                zmq::poll(pitems, std::chrono::duration<long int>::max());
            } catch (zmq::error_t const &e) {
                if (errno != EINTR || pending_interrupt())
                    Rf_error(e.what());
            }
            if (pitems[1].revents > 0)
                Rf_error("Unexpected peer disconnect");
            total_sock_ev = pitems[0].revents;
        } while (total_sock_ev == 0);
    }
};
