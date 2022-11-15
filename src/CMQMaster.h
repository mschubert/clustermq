#include <Rcpp.h>
#include "common.h"

class CMQMaster {
public:
    CMQMaster(): ctx(new zmq::context_t(3)) {}
    ~CMQMaster() { close(); }

    SEXP context() {
        Rcpp::XPtr<zmq::context_t> p(ctx, true);
        return p;
    }

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
        if (ctx != nullptr) {
            ctx->close();
            ctx = nullptr;
        }
    }

    SEXP recv(int timeout=-1) {
//        if (peers.size() == 0)
//            Rf_error("Trying to receive data without workers");

        auto msgs = poll_recv(timeout);
        return msg2r(msgs[3], true);
    }

    void send(SEXP cmd, bool more) {
        auto status = wlife_t::active;
        if (!more)
            status = wlife_t::shutdown;

        auto &w = peers[cur];
        std::set<std::string> new_env;
        std::set_difference(env_names.begin(), env_names.end(), w.env.begin(), w.env.end(),
                std::inserter(new_env, new_env.end()));

        zmq::multipart_t mp;
        mp.push_back(str2msg(cur));
        mp.push_back(zmq::message_t(0));
        mp.push_back(int2msg(status));
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

    Rcpp::List cleanup(int timeout=5000) {
        env.clear();
        poll_recv(timeout);
        close();
        Rcpp::List re(on_shutdown.size());
        for (int i=0; i<on_shutdown.size(); i++)
            re[i] = std::move(on_shutdown[i]);
        return re;
    }

private:
    struct worker_t {
        std::set<std::string> env;
        SEXP call {R_NilValue};
        wlife_t status;
    };

    zmq::context_t *ctx {nullptr};
    zmq::socket_t sock;
    std::string cur;
    std::unordered_map<std::string, worker_t> peers;
    std::unordered_map<std::string, zmq::message_t> env;
    std::set<std::string> env_names;
    std::vector<SEXP> on_shutdown;

    std::vector<zmq::message_t> poll_recv(int timeout=-1) {
        auto pitems = std::vector<zmq::pollitem_t>(1);
        pitems[0].socket = sock;
        pitems[0].events = ZMQ_POLLIN;

        auto start = Time::now();
        auto time_ms = std::chrono::milliseconds(timeout);
        std::vector<zmq::message_t> msgs;
        while (true) {
            try {
                zmq::poll(pitems, time_ms);
            } catch (zmq::error_t const &e) {
                if (errno != EINTR || pending_interrupt())
                    Rf_error(e.what());
            }

            if (timeout != -1) {
                auto now = Time::now();
                time_ms -= std::chrono::duration_cast<ms>(now - start);
                if (time_ms.count() <= 0)
                    Rf_error("socket timeout reached");
                start = now;
            }

            if (pitems[0].revents == 0)
                continue;

            recv_multipart(sock, std::back_inserter(msgs));
            if (msgs.size() != 4)
                Rf_error("unexpected message format");

            cur = std::string(reinterpret_cast<const char*>(msgs[0].data()), msgs[0].size());
            auto &w = peers[cur];
            w.status = *static_cast<wlife_t*>(msgs[2].data());
            w.call = R_NilValue;
            if (w.status != wlife_t::shutdown)
                break;

            on_shutdown.push_back(msg2r(msgs[3], true));
            send(R_NilValue, false);
            peers.erase(cur);
            msgs.clear();
        };

        return msgs;
    }
};
