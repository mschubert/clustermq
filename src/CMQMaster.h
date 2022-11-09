#include <Rcpp.h>
#include "common.h"

class CMQMaster { // : public ZeroMQ {
public:
    CMQMaster(int threads=1): ctx(new zmq::context_t(threads)) {
        external_context = false;
    }
    CMQMaster(SEXP ctx_): ctx(Rcpp::as<Rcpp::XPtr<zmq::context_t>>(ctx_)) {}
    ~CMQMaster() { close(); }

    std::string listen(Rcpp::CharacterVector addrs) {
        sock = zmq::socket_t(*ctx, ZMQ_ROUTER);
        sock.set(zmq::sockopt::router_mandatory, 1);
        sock.set(zmq::sockopt::router_notify, ZMQ_NOTIFY_DISCONNECT);

        int i;
        for (i=0; i<addrs.length(); i++) {
            auto addr = Rcpp::as<std::string>(addrs[i]);
            try {
                sock.bind(addr);
                return sock.get(zmq::sockopt::last_endpoint);
            } catch(zmq::error_t const &e) {
                if (errno != EADDRINUSE)
                    Rf_error(e.what());
            }
        }
        Rf_error("Could not bind port to any address in provided pool");
    }

    void close() {
        if (sock.handle() != nullptr) {
            sock.set(zmq::sockopt::linger, 0);
            sock.close();
        }
        if (!external_context) {
            ctx->close();
            delete ctx;
            ctx = nullptr;
        }
    }

    SEXP recv(int timeout=-1) {
//        if (peers.size() == 0)
//            Rf_error("Trying to receive data without workers");

        auto ev = Rcpp::as<int>(poll(timeout));
        if (ev == 0)
            Rf_error("Socket timeout reached");

        std::vector<zmq::message_t> msgs;
        recv_multipart(sock, std::back_inserter(msgs));

        if (msgs.size() < 3)
            Rf_error("no content received, should not happen?");

        cur = std::string(reinterpret_cast<const char*>(msgs[0].data()), msgs[0].size());
        peers[cur].call = R_NilValue;
        return msg2r(msgs[2], true);
    }

    void send(SEXP cmd) {
        auto &w = peers[cur];
        std::set<std::string> new_env;
        std::set_difference(env_names.begin(), env_names.end(), w.env.begin(), w.env.end(),
                std::inserter(new_env, new_env.end()));

        zmq::multipart_t mp;
        mp.push_back(str2msg(cur));
        mp.push_back(zmq::message_t(0));
        mp.push_back(int2msg(wlife_t::active));
        mp.push_back(r2msg(cmd));

        for (auto &str : new_env) {
            w.env.insert(str);
            zmq::message_t msg;
            msg.copy(env[str]);
            mp.push_back(std::move(msg));
        }

        w.call = cmd;
        mp.send(sock);
    }

    void add_env(std::string name, SEXP obj) {
        for (auto &w : peers)
            w.second.env.erase(name);
        auto named = Rcpp::List::create(Rcpp::Named(name) = obj);
        env_names.insert(name);
        env[name] = r2msg(R_serialize(named, R_NilValue));
    }
    void add_pkg(Rcpp::CharacterVector pkg) {
        add_env("package:" + Rcpp::as<std::string>(pkg), pkg);
    }

private:
    struct worker_t {
        std::set<std::string> env;
        SEXP call {R_NilValue};
        wlife_t status;
    };

    bool external_context {true};
    zmq::context_t *ctx;
    zmq::socket_t sock;
    std::string cur;
    std::unordered_map<std::string, worker_t> peers;
    std::unordered_map<std::string, zmq::message_t> env;
    std::set<std::string> env_names;

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
                    auto now = Time::now();
                    time_ms -= std::chrono::duration_cast<ms>(now - start);
                    if (time_ms.count() <= 0)
                        break;
                    start = now;
                }
            }
            result[0] = pitems[0].revents;
            total_sock_ev += pitems[0].revents;
        } while (total_sock_ev == 0);

        return result;
    }
};
