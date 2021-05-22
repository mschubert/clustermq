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

    void send(SEXP data) {
        send(data, false);
    }
    void send(SEXP data, bool send_more=false) {
        auto flags = zmq::send_flags::none;
        if (send_more)
            flags = flags | zmq::send_flags::sndmore;
        if (TYPEOF(data) != RAWSXP)
            data = R_serialize(data, R_NilValue);
        zmq::message_t content(Rf_xlength(data));
        memcpy(content.data(), RAW(data), Rf_xlength(data));
        sock.send(content, flags);
    }
    SEXP receive() {
        poll();
        zmq::message_t msg;
        sock.recv(msg, zmq::recv_flags::none);
        SEXP ans = Rf_allocVector(RAWSXP, msg.size());
        memcpy(RAW(ans), msg.data(), msg.size());
        return R_unserialize(ans);
    }

    SEXP get_data_redirect(std::string addr, SEXP data) {
        //todo: this should ideally also be monitored (although short connection)
        auto rsock = zmq::socket_t(*ctx, ZMQ_REQ);
        rsock.set(zmq::sockopt::connect_timeout, 10000);
        rsock.connect(addr);

        data = R_serialize(data, R_NilValue);
        zmq::message_t content(Rf_xlength(data));
        memcpy(content.data(), RAW(data), Rf_xlength(data));
        rsock.send(content, zmq::send_flags::none);

        zmq::message_t msg;
        rsock.recv(msg, zmq::recv_flags::none);
        SEXP ans = Rf_allocVector(RAWSXP, msg.size());
        memcpy(RAW(ans), msg.data(), msg.size());

        rsock.set(zmq::sockopt::linger, 0);
        rsock.close();

        return R_unserialize(ans);
    }

    void main_loop() {
    }

private:
    zmq::context_t *ctx;
    zmq::socket_t sock;
    zmq::socket_t mon;

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
