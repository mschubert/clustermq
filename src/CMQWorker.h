#include <Rcpp.h>
#include "common.h"

class CMQWorker {
public:
    CMQWorker(): ctx(new zmq::context_t(1)) {
        external_context = false;
    }
    CMQWorker(SEXP ctx_): ctx(Rcpp::as<Rcpp::XPtr<zmq::context_t>>(ctx_)) {}
    ~CMQWorker() { close(); }

    void connect(std::string addr, int timeout=10000) {
        sock = zmq::socket_t(*ctx, ZMQ_REQ);
        // timeout would need ZMQ_RECONNECT_STOP_CONN_REFUSED (draft, no C++ yet) to work
        sock.set(zmq::sockopt::connect_timeout, timeout);
        sock.set(zmq::sockopt::immediate, 1);

        if (mon.handle() == nullptr) {
            if (zmq_socket_monitor(sock, "inproc://monitor", ZMQ_EVENT_DISCONNECTED) < 0)
                Rf_error("failed to create socket monitor");
            mon = zmq::socket_t(*ctx, ZMQ_PAIR);
            mon.connect("inproc://monitor");
        }

        try {
            sock.connect(addr);
            sock.send(int2msg(wlife_t::active), zmq::send_flags::sndmore);
            sock.send(r2msg(R_NilValue), zmq::send_flags::none);
        } catch (zmq::error_t const &e) {
            Rf_error(e.what());
        }
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

    bool process_one() {
        std::vector<zmq::message_t> msgs;
        recv_multipart(sock, std::back_inserter(msgs));
        auto status = *static_cast<wlife_t*>(msgs[0].data());
        auto cmd = msg2r(msgs[1], true);

        for (auto it=msgs.begin()+2; it<msgs.end(); it++) {
            Rcpp::List obj = msg2r(*it, true);
            env.assign(obj.names(), obj[0]);
            if (Rcpp::as<std::string>(obj.names()).compare(0, 8, "package:") == 0)
                load_pkg(obj[0]);
        }

        int err = 0;
        SEXP eval = PROTECT(R_tryEvalSilent(Rcpp::as<Rcpp::List>(cmd)[0], env, &err));
        if (err) {
            auto cmq = Rcpp::Environment::namespace_env("clustermq");
            Rcpp::Function wrap_error = cmq["wrap_error"];
            eval = wrap_error(cmd);
        }
        sock.send(int2msg(status), zmq::send_flags::sndmore);
        sock.send(r2msg(eval), zmq::send_flags::none);
        UNPROTECT(1);
        return status == wlife_t::active;
    }

private:
    bool external_context {true};
    zmq::context_t *ctx {nullptr};
    zmq::socket_t sock;
    zmq::socket_t mon;
    Rcpp::Environment env {1};
    Rcpp::Function load_pkg {"library"};
};
