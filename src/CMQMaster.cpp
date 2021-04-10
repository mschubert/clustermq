#include <Rcpp.h>
#include "MonitoredSocket.hpp"
#include "ZeroMQ.hpp"

class CMQMaster { // : public ZeroMQ {
public:
//    CMQMaster(zmq::context_t *ctx_): ctx(ctx_) {
    CMQMaster(int threads=1): ctx(new zmq::context_t(threads)) {
        sock = zmq::socket_t(*ctx, ZMQ_ROUTER);
        sock.setsockopt(ZMQ_ROUTER_MANDATORY, 1);
        sock.setsockopt(ZMQ_ROUTER_NOTIFY, ZMQ_NOTIFY_DISCONNECT);
    }
    ~CMQMaster() {
        ctx->close();
        delete ctx;
    }

    std::string listen(Rcpp::CharacterVector addrs) {
        int i;
        for (i=0; i<addrs.length(); i++) {
            auto addr = Rcpp::as<std::string>(addrs[i]);
            try {
                sock.bind(addr);
            } catch(zmq::error_t const &e) {
                if (errno != EADDRINUSE)
                    Rf_error(e.what());
            }
            char option_value[1024];
            size_t option_value_len = sizeof(option_value);
            sock.getsockopt(ZMQ_LAST_ENDPOINT, option_value, &option_value_len);
            return std::string(option_value);
        }
        Rf_error("Could not bind port after ", i, " tries");
    }
    // temporary for refactor, Rcpp errors if only defined in base class (or same name)
    void send_work(SEXP data) {
            std::cerr << "setting worker " << cur_s << " active\n";
        peer_active[cur_s] = true;
        send(cur, false, true);
        send_null(false, true);
        send(data, false, false);
    }
    void send_shutdown(SEXP data) {
            std::cerr << "setting worker " << cur_s << " inactive\n";
        peer_active[cur_s] = false;
        send(cur, false, true);
        send_null(false, true);
        send(data, false, false);
    }
    SEXP receive2() {
        cur = receive(false, false);
        cur_s = std::string(reinterpret_cast<const char*>(RAW(cur)), Rf_xlength(cur));
        auto null = receive(false, false);
        SEXP msg;
        if (sock.get(zmq::sockopt::rcvmore)) {
            msg = receive(true, true);
        } else {
            std::cerr << "notify disconnect from " << cur_s << "\n";
            if (peer_active[cur_s])
                Rf_error("Unexpected worker disconnect: check your logs");
            peer_active.erase(cur_s);
            msg = R_NilValue;
        }
        std::cerr << peer_active.size() << " peers\n";
        return msg;
    }
    Rcpp::IntegerVector poll2(int timeout=-1) {
        return poll(timeout);
    }

    void main_loop() {
    }

private:
//    MasterSocket * sock;
    zmq::context_t *ctx;
    zmq::socket_t sock;
    SEXP cur;
    std::string cur_s;

    // can track which call ids each peer works on if required
    std::unordered_map<std::string, bool> peer_active;

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
        sock.send(message, flags);
    }
    void send_null(bool dont_wait=false, bool send_more=false) {
        auto flags = zmq::send_flags::none;
        if (dont_wait)
            flags = flags | zmq::send_flags::dontwait;
        if (send_more)
            flags = flags | zmq::send_flags::sndmore;

        zmq::message_t message(0);
        sock.send(message, flags);
    }
    SEXP receive(bool dont_wait=false, bool unserialize=true) {
        auto flags = zmq::recv_flags::none;
        if (dont_wait)
            flags = flags | zmq::recv_flags::dontwait;

        zmq::message_t message;
        sock.recv(message, flags);
        SEXP ans = Rf_allocVector(RAWSXP, message.size());
        memcpy(RAW(ans), message.data(), message.size());
        if (unserialize)
            return R_unserialize(ans);
        else
            return ans;
    }

    Rcpp::IntegerVector poll(int timeout=-1) {
        auto pitems = std::vector<zmq::pollitem_t>(1);
        pitems[0].socket = sock;
        pitems[0].events = ZMQ_POLLIN;

        auto start = Time::now();
        int total_sock_ev = 0;
        auto result = Rcpp::IntegerVector(1);
        do {
            try {
                zmq::poll(pitems, timeout);
            } catch (zmq::error_t const &e) {
                if (errno != EINTR || pending_interrupt())
                    Rf_error(e.what());
                if (timeout != -1) {
                    ms dt = std::chrono::duration_cast<ms>(Time::now() - start);
                    timeout = timeout - dt.count();
                    if (timeout <= 0)
                        break;
                }
            }
            result[0] = pitems[0].revents;
            total_sock_ev += pitems[0].revents;
        } while (total_sock_ev == 0);

        return result;
    }
};

RCPP_MODULE(cmq_master) {
    using namespace Rcpp;
    void (CMQMaster::*send_work)(SEXP) = &CMQMaster::send_work ;
    void (CMQMaster::*send_shutdown)(SEXP) = &CMQMaster::send_shutdown ;
    class_<CMQMaster>("CMQMaster")
        .constructor()
//        .constructor<zmq::context_t*>()
        .method("main_loop", &CMQMaster::main_loop)
        .method("listen", &CMQMaster::listen)
        .method("send_work", send_work)
        .method("send_shutdown", send_shutdown)
        .method("receive", &CMQMaster::receive2)
        .method("poll", &CMQMaster::poll2)
    ;
}
