#include <Rcpp.h>
#include "MonitoredSocket.hpp"
#include "zeromq.hpp"

class WorkerSocket : public MonitoredSocket {
public:
    WorkerSocket(zmq::context_t & ctx, std::string addr):
            MonitoredSocket(ctx, ZMQ_REQ, "worker") {
        connect(addr);
    }
//    ~WorkerSocket() { // error: use of deleted function ‘WorkerSocket::WorkerSocket(const WorkerSocket&)’
//    }

private:
};

class CMQWorker : public ZeroMQ {
public:
    CMQWorker(std::string addr): sock(new WorkerSocket(ctx, addr)) {
        add_socket(sock, "worker"); // ptr deleted by base destructor
    }

    // temporary for refactor, Rcpp errors if only defined in base class (or same name)
    void disconnect2() {
        disconnect("worker");
    }
    void send2(SEXP data) {
        send(data, "worker", false, false);
    }
    void send3(SEXP data, bool send_more=false) {
        send(data, "worker", false, send_more);
    }
    SEXP receive2() {
        return receive("worker", false, true);
    }
    Rcpp::IntegerVector poll2(int timeout=-1) {
        return poll("worker", timeout);
    }

    void main_loop() {
    }

private:
    WorkerSocket * sock;
};

RCPP_MODULE(cmq_worker) {
    using namespace Rcpp;
    class_<CMQWorker>("CMQWorker")
        .constructor<std::string>()
        .method("main_loop", &CMQWorker::main_loop)
        .method("disconnect", &CMQWorker::disconnect2)
        .method("send", &CMQWorker::send2)
        .method("send2", &CMQWorker::send3)
        .method("receive", &CMQWorker::receive2)
        .method("poll", &CMQWorker::poll2)
    ;
}
