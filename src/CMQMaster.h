#include <Rcpp.h>
#include "ZeroMQ.h"

class CMQMaster { // : public ZeroMQ {
public:
    CMQMaster(int threads=1): CMQMaster(new zmq::context_t(threads)) {
        external_context = false;
    }
    CMQMaster(zmq::context_t *ctx_): ctx(ctx_) {
        sock = zmq::socket_t(*ctx, ZMQ_ROUTER);
        sock.set(zmq::sockopt::router_mandatory, 1);
        sock.set(zmq::sockopt::router_notify, ZMQ_NOTIFY_DISCONNECT);
    }
    ~CMQMaster() {
        sock.set(zmq::sockopt::linger, 0);
        sock.close();
        if (!external_context) {
            ctx->close();
            delete ctx;
        }
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
            return sock.get(zmq::sockopt::last_endpoint);
        }
        Rf_error("Could not bind port after ", i, " tries");
    }

    SEXP recv_one(int timeout=-1) {
//        if (peers.size() == 0)
//            Rf_error("Trying to receive data without workers");

        auto ev = Rcpp::as<int>(poll(timeout));
        if (ev == 0)
            Rf_error("Socket timeout reached");

        std::vector<zmq::message_t> msgs;
        auto res = recv_multipart(sock, std::back_inserter(msgs));

        if (msgs.size() < 3)
            Rf_error("no content received, should not happen?");

        cur = std::string(reinterpret_cast<const char*>(msgs[0].data()), msgs[0].size());
        return msg2r(msgs[2]);
    }

    void send_one(SEXP cmd) {
        // unserialize, read env
        // add frams of what's not in env to send

        send(cmd); //TODO: 
    }

    void add_env(std::string name, SEXP obj) {
        //todo: how to encode names objs here?
        auto serial = R_serialize(obj, R_NilValue);
        env[name] = r2msg(serial);
    }

private:
    struct worker_t {
        std::vector<std::string> env;
        SEXP call {R_NilValue};
    };

    zmq::context_t *ctx;
    bool external_context {true};
    zmq::socket_t sock;
    std::string cur;
    std::unordered_map<std::string, worker_t> peers;
    std::unordered_map<std::string, zmq::message_t> env;

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

    void send(SEXP data) {
        sock.send(str2msg(cur), zmq::send_flags::sndmore);
        sock.send(zmq::message_t(0), zmq::send_flags::sndmore);
        sock.send(r2msg(data), zmq::send_flags::none);
    }
    Rcpp::IntegerVector poll(int timeout=-1) {
        auto pitems = std::vector<zmq::pollitem_t>(1);
        pitems[0].socket = sock;
        pitems[0].events = ZMQ_POLLIN;

        auto start = Time::now();
        auto time_ms = std::chrono::milliseconds(timeout);
        int total_sock_ev = 0;
        auto result = Rcpp::IntegerVector(1);
        do {
            try {
                zmq::poll(pitems, time_ms);
            } catch (zmq::error_t const &e) {
                if (errno != EINTR || pending_interrupt())
                    Rf_error(e.what());
                if (timeout != -1) {
                    time_ms -= std::chrono::duration_cast<ms>(Time::now() - start);
                    if (time_ms.count() <= 0)
                        break;
                }
            }
            result[0] = pitems[0].revents;
            total_sock_ev += pitems[0].revents;
        } while (total_sock_ev == 0);

        return result;
    }
};
