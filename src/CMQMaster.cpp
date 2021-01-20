#include <Rcpp.h>
#include "MonitoredSocket.hpp"
#include "ZeroMQ.hpp"

class MasterSocket : public MonitoredSocket {
public:
    MasterSocket(zmq::context_t * ctx, std::string addr):
            MonitoredSocket(ctx, ZMQ_REQ, "master") {
        connect(addr);
    }
};

class CMQMaster : public ZeroMQ {
public:
    CMQMaster(std::string addr): sock(new MasterSocket(ctx, addr)) {
        add_socket(sock, "master"); // ptr deleted by base destructor
    }

    // temporary for refactor, Rcpp errors if only defined in base class (or same name)
    void disconnect2() {
        disconnect("master");
    }
    void send2(SEXP data) {
        send(data, "master", false, false);
    }
    void send2(SEXP data, bool send_more=false) {
        send(data, "master", false, send_more);
    }
    SEXP receive2() {
        return receive("master", false, true);
    }
    Rcpp::IntegerVector poll2(int timeout=-1) {
        return poll("master", timeout);
    }

    void main_loop() {
    }

private:
    MasterSocket * sock;
};

RCPP_MODULE(cmq_master) {
    using namespace Rcpp;
    void (CMQMaster::*send_1)(SEXP) = &CMQMaster::send2 ;
    void (CMQMaster::*send_2)(SEXP, bool) = &CMQMaster::send2 ;
    class_<CMQMaster>("CMQMaster")
        .constructor<std::string>()
        .method("main_loop", &CMQMaster::main_loop)
        .method("disconnect", &CMQMaster::disconnect2)
        .method("send", send_1)
        .method("send", send_2)
        .method("receive", &CMQMaster::receive2)
        .method("poll", &CMQMaster::poll2)
    ;
}
