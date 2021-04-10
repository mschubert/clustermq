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
        int linger = 0;
        sock.setsockopt(ZMQ_LINGER, &linger, sizeof(linger));
        sock.close();
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
    void send_work(SEXP data) {
            std::cerr << "setting worker " << cur << " active\n";
        peer_active[cur] = true;
        send(data);
    }
    void send_shutdown(SEXP data) {
            std::cerr << "setting worker " << cur << " inactive\n";
        peer_active[cur] = false;
        send(data);
    }

    void main_loop() {
    }

    SEXP poll_recv(int timeout=-1) {
//        if (peer_active.size() == 0)
//            Rf_error("Trying to receive data without workers");

        int ev = 0;
        SEXP msg;
        do {
            ev = Rcpp::as<int>(poll(timeout));
            if (ev == 0)
                Rf_error("Socket timeout reached");

            zmq::message_t identity;
            sock.recv(identity, zmq::recv_flags::none);
            cur = std::string(reinterpret_cast<const char*>(identity.data()), identity.size());

            zmq::message_t delimiter;
            sock.recv(delimiter, zmq::recv_flags::none);

            if (sock.get(zmq::sockopt::rcvmore)) {
                zmq::message_t content;
                sock.recv(content, zmq::recv_flags::none);
                msg = Rf_allocVector(RAWSXP, content.size());
                memcpy(RAW(msg), content.data(), content.size());
                msg = R_unserialize(msg);
            } else {
                std::cerr << "notify disconnect from " << cur << "\n";
                if (peer_active[cur])
                    Rf_error("Unexpected worker disconnect: check your logs");
                peer_active.erase(cur);
                ev = 0;
            }

            std::cerr << peer_active.size() << " peers\n";
        } while (ev == 0);

        return msg;
    }

private:
    zmq::context_t *ctx;
    zmq::socket_t sock;
    std::string cur;
    std::unordered_map<std::string, bool> peer_active;
    // ^can track which call ids each peer works on if required

    void send(SEXP data) {
        zmq::message_t identity(cur.length());
        memcpy(identity.data(), cur.data(), cur.length());
        sock.send(identity, zmq::send_flags::sndmore);

        zmq::message_t delimiter(0);
        sock.send(delimiter, zmq::send_flags::sndmore);

        if (TYPEOF(data) != RAWSXP)
            data = R_serialize(data, R_NilValue);
        zmq::message_t content(Rf_xlength(data));
        memcpy(content.data(), RAW(data), Rf_xlength(data));
        sock.send(content, zmq::send_flags::none);
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
    class_<CMQMaster>("CMQMaster")
        .constructor()
//        .constructor<zmq::context_t*>()
        .method("main_loop", &CMQMaster::main_loop)
        .method("listen", &CMQMaster::listen)
        .method("send_work", &CMQMaster::send_work)
        .method("send_shutdown", &CMQMaster::send_shutdown)
        .method("poll_recv", &CMQMaster::poll_recv)
    ;
}
