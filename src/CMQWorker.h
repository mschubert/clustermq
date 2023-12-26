#include <Rcpp.h>
#include "common.h"

class CMQWorker {
public:
    CMQWorker(): ctx(new zmq::context_t(1)) {
        external_context = false;
    }
    CMQWorker(SEXP ctx_): ctx(Rcpp::as<Rcpp::XPtr<zmq::context_t>>(ctx_)) {}
    ~CMQWorker() { close(); }

    void connect(std::string addr, int timeout=5000) {
        sock = zmq::socket_t(*ctx, ZMQ_REQ);
        // timeout would need ZMQ_RECONNECT_STOP_CONN_REFUSED (draft, no C++ yet) to work
        sock.set(zmq::sockopt::connect_timeout, timeout);
        sock.set(zmq::sockopt::immediate, 1);

        if (mon.handle() == nullptr) {
            if (zmq_socket_monitor(sock, "inproc://monitor", ZMQ_EVENT_DISCONNECTED) < 0)
                Rcpp::stop("failed to create socket monitor");
            mon = zmq::socket_t(*ctx, ZMQ_PAIR);
            mon.connect("inproc://monitor");
        }

        try {
            sock.connect(addr);
            check_send_ready(timeout);
            sock.send(int2msg(wlife_t::active), zmq::send_flags::sndmore);
            sock.send(r2msg(proc_time()), zmq::send_flags::sndmore);
            sock.send(r2msg(gc()), zmq::send_flags::sndmore);
            sock.send(r2msg(R_NilValue), zmq::send_flags::none);
        } catch (zmq::error_t const &e) {
            Rcpp::stop(e.what());
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
        if (!external_context && ctx != nullptr) {
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
                zmq::poll(pitems, std::chrono::milliseconds{-1});
            } catch (zmq::error_t const &e) {
                if (errno != EINTR || pending_interrupt())
                    Rcpp::stop(e.what());
            }
            if (pitems[1].revents > 0)
                Rcpp::stop("Unexpected peer disconnect");
            total_sock_ev = pitems[0].revents;
        } while (total_sock_ev == 0);
    }

    bool process_one() {
        std::vector<zmq::message_t> msgs;
        auto n = recv_multipart(sock, std::back_inserter(msgs));

//        std::cout << "Received message: ";
//        for (int i=0; i<msgs.size(); i++)
//            std::cout << msgs[i].size() << " ";
//        std::cout << "\n";
//        for (int i=0; i<msgs.size(); i++)
//            std::cout << i << ": " << msgs[i].str() << "\n";

        if (msg2wlife_t(msgs[0]) == wlife_t::shutdown) {
            close();
            return false;
        }
        for (auto it=msgs.begin()+3; it<msgs.end(); it+=2) {
            std::string name = (it-1)->to_string();
            if (name.compare(0, 8, "package:") == 0)
                load_pkg(name.substr(8, std::string::npos));
            else
                env.assign(name, msg2r(std::move(*it), true));
        }

        SEXP cmd, eval, time, mem;
        PROTECT(cmd = msg2r(std::move(msgs[1]), true));
        int err = 0;
        PROTECT(eval = R_tryEvalSilent(Rcpp::as<Rcpp::List>(cmd)[0], env, &err));
        if (err) {
            auto cmq = Rcpp::Environment::namespace_env("clustermq");
            Rcpp::Function wrap_error = cmq["wrap_error"];
            UNPROTECT(1);
            PROTECT(eval = wrap_error(cmd));
        }
        PROTECT(time = proc_time());
        PROTECT(mem = gc());
        sock.send(int2msg(wlife_t::active), zmq::send_flags::sndmore);
        sock.send(r2msg(time), zmq::send_flags::sndmore);
        sock.send(r2msg(mem), zmq::send_flags::sndmore);
        sock.send(r2msg(eval), zmq::send_flags::none);
        UNPROTECT(4);
        return true;
    }

private:
    bool external_context {true};
    zmq::context_t *ctx {nullptr};
    zmq::socket_t sock;
    zmq::socket_t mon;
    Rcpp::Environment env {1};
    Rcpp::Function load_pkg {"library"};
    Rcpp::Function proc_time {"proc.time"};
    Rcpp::Function gc {"gc"};

    void check_send_ready(int timeout=5000) {
        auto pitems = std::vector<zmq::pollitem_t>(1);
        pitems[0].socket = sock;
        pitems[0].events = ZMQ_POLLOUT;

        auto time_ms = std::chrono::milliseconds(timeout);
        auto time_left = time_ms;
        auto start = Time::now();

        do {
            try {
                zmq::poll(pitems, time_left);
            } catch (zmq::error_t const &e) {
                if (errno != EINTR || pending_interrupt())
                    Rcpp::stop(e.what());
            }

            auto ms_diff = std::chrono::duration_cast<ms>(Time::now() - start);
            time_left = time_ms - ms_diff;
            if (time_left.count() < 0) {
                std::ostringstream err;
                err << "Connection failed after " << ms_diff.count() << " ms\n";
                throw Rcpp::exception(err.str().c_str());
            }
        } while (pitems[0].revents == 0);
    }
};
