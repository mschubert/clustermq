#include <Rcpp.h>
#include "MonitoredSocket.hpp"
#include "ZeroMQ.hpp"

class MasterSocket : public MonitoredSocket {
public:
    MasterSocket(zmq::context_t * ctx): MonitoredSocket(ctx, ZMQ_ROUTER, "master") {}

/* we can not link this to the source
    void handle_monitor_event() {
        auto ev = recv_monitor_event();
        std::cerr << "recv ev: " << ev.event << " @ " << ev.addr << "\n";
        if (ev.event == ZMQ_EVENT_HANDSHAKE_SUCCEEDED)
            std::cerr << "peer accepted\n";
        if (ev.event == ZMQ_EVENT_DISCONNECTED)
            std::cerr << "peer disconnected\n";
    } */
};

class CMQMaster : public ZeroMQ {
public:
//    CMQMaster(zmq::context_t * ctx): ZeroMQ(ctx) {
//        CMQMaster();
//    }
    CMQMaster() {
        sock = new MasterSocket(ctx); // ptr deleted by base destructor
        add_socket(sock, "master");
    }

    std::string listen2(Rcpp::CharacterVector addrs) {
        return sock->listen(addrs);
    }
    // temporary for refactor, Rcpp errors if only defined in base class (or same name)
    void disconnect2() {
        disconnect("master");
    }
    void send2(SEXP data) {
        send2(data, false);
    }
    void send2(SEXP data, bool send_more=false) {
        send(cur, "master", false, true);
        send_null("master", false, true);
        send(data, "master", false, send_more);
    }
    SEXP receive2() {
        cur = receive("master", false, false);
        auto null = receive("master", false, false);
        return receive("master", false, true);
    }
    Rcpp::IntegerVector poll2(int timeout=-1) {
        return poll("master", timeout);
    }

    void main_loop() {
    }

private:
    MasterSocket * sock;
    SEXP cur;
};

RCPP_MODULE(cmq_master) {
    using namespace Rcpp;
    void (CMQMaster::*send_1)(SEXP) = &CMQMaster::send2 ;
    void (CMQMaster::*send_2)(SEXP, bool) = &CMQMaster::send2 ;
    class_<CMQMaster>("CMQMaster")
        .constructor()
//        .constructor<zmq::context_t*>()
        .method("main_loop", &CMQMaster::main_loop)
        .method("listen", &CMQMaster::listen2)
        .method("disconnect", &CMQMaster::disconnect2)
        .method("send", send_1)
        .method("send", send_2)
        .method("receive", &CMQMaster::receive2)
        .method("poll", &CMQMaster::poll2)
    ;
}
