#include <Rcpp.h>
#include "ZeroMQ.hpp"

class CMQWorker { // : public ZeroMQ {
public:
    CMQWorker(std::string addr): ctx(new zmq::context_t(1)) {
        sock = zmq::socket_t(*ctx, ZMQ_REQ);
        sock.set(zmq::sockopt::connect_timeout, 10000);
        sock.connect(addr);
    }
    ~CMQWorker() {
        sock.set(zmq::sockopt::linger, 0);
        sock.close();
        ctx->close();
        delete ctx;
    }

    void send(SEXP data) {
        if (TYPEOF(data) != RAWSXP)
            data = R_serialize(data, R_NilValue);
        zmq::message_t content(Rf_xlength(data));
        memcpy(content.data(), RAW(data), Rf_xlength(data));
        sock.send(content, zmq::send_flags::none);
    }
    SEXP receive() {
        zmq::message_t msg;
        sock.recv(msg, zmq::recv_flags::none);
        SEXP ans = Rf_allocVector(RAWSXP, msg.size());
        memcpy(RAW(ans), msg.data(), msg.size());
        return R_unserialize(ans);
    }

    SEXP get_data_redirect(std::string addr, SEXP data) {
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
};

RCPP_MODULE(cmq_worker) {
    using namespace Rcpp;
    class_<CMQWorker>("CMQWorker")
        .constructor<std::string>()
        .method("main_loop", &CMQWorker::main_loop)
        .method("get_data_redirect", &CMQWorker::get_data_redirect)
        .method("send", &CMQWorker::send)
        .method("receive", &CMQWorker::receive)
    ;
}
