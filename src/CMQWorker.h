#include <Rcpp.h>
#include "ZeroMQ.h"

class CMQWorker { // : public ZeroMQ {
public:
    CMQWorker(std::string addr): ctx(new zmq::context_t(1)) {
        sock = zmq::socket_t(*ctx, ZMQ_REQ);
        sock.set(zmq::sockopt::connect_timeout, 10000);
        sock.connect(addr);

        int rc = zmq_socket_monitor(sock, "inproc://monitor", ZMQ_EVENT_DISCONNECTED);
        if (rc < 0) // C API needs return value check
            Rf_error("failed to create socket monitor");
        mon = zmq::socket_t(*ctx, ZMQ_PAIR);
        mon.connect("inproc://monitor");
    }
    ~CMQWorker() {
        mon.set(zmq::sockopt::linger, 0);
        mon.close();
        sock.set(zmq::sockopt::linger, 10000);
        sock.close();
        ctx->close();
        delete ctx;
    }

    void send(SEXP data) { // default args don't work from R
        send(data, false);
    }
    void send(SEXP data, bool send_more) {
        auto flags = zmq::send_flags::none;
        if (send_more)
            flags = flags | zmq::send_flags::sndmore;
        sock.send(r2msg(data), flags);
    }
    SEXP receive() {
        poll();
        zmq::message_t msg;
        sock.recv(msg, zmq::recv_flags::none);
        return msg2r(msg);
    }

    void process_one() {
        std::vector<zmq::message_t> msgs;
        auto res = recv_multipart(sock, std::back_inserter(msgs));
        auto cmd = msg2r(msgs[0]);

        //TODO: for index 1..n add SEXPs to env
//        for ()
//            env[] = ;

        SEXP eval = Rcpp::Rcpp_eval(cmd, Rcpp::Environment::global_env());
        send(eval);
    }

private:
    zmq::context_t *ctx;
    zmq::socket_t sock;
    zmq::socket_t mon;
    Rcpp::Environment env;

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
