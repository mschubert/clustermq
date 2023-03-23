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

    void close(int timeout=0) {
        if (sock.handle() != nullptr) {
            sock.set(zmq::sockopt::linger, timeout);
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
        return msg2r(msgs[3+has_proxy], true);
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
        if (has_proxy != 0)
            mp.push_back(str2msg(std::string("proxy")));
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

        // if the master connects via ssh, remove env items after sending once?

        w.call = cmd;
        mp.send(sock);
    }

    void proxy_submit_cmd(SEXP args, int timeout=10000) {
        auto msgs = poll_recv(timeout);
        // msgs[0] == "proxy" routing id
        // msgs[1] == delimiter
        // msgs[2] == wlife_t::proxy_cmd
        // msgs[3] == R_NilValue

        zmq::multipart_t mp;
        mp.push_back(str2msg(cur));
        mp.push_back(zmq::message_t(0));
        mp.push_back(int2msg(wlife_t::proxy_cmd));
        mp.push_back(r2msg(args));
        mp.send(sock);
    }
    void proxy_shutdown() {
        zmq::multipart_t mp;
        mp.push_back(str2msg("proxy"));
        mp.push_back(zmq::message_t(0));
        mp.push_back(int2msg(wlife_t::proxy_shutdown));
        mp.push_back(r2msg(R_NilValue));
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
        sock.set(zmq::sockopt::router_mandatory, 0);
        env.clear();
        while(peers.size() > has_proxy) {
            try {
                poll_recv(timeout);
            } catch (zmq::error_t const &e) {
                Rcpp::warning(e.what());
            }
        }
        if (has_proxy)
            proxy_shutdown();
        close(timeout);
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
    int has_proxy {0};
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

        std::vector<zmq::message_t> msgs;
        auto time_ms = std::chrono::milliseconds(timeout);
        auto start = Time::now();
        while (true) {
            try {
                zmq::poll(pitems, time_ms);
            } catch (zmq::error_t const &e) {
                if (errno != EINTR || pending_interrupt())
                    Rf_error(e.what());
            }

            if (pitems[0].revents == 0) {
                auto now = Time::now();
                time_ms -= std::chrono::duration_cast<ms>(now - start);
                start = now;
                if (timeout != -1 && time_ms.count() <= 0)
                    Rf_error("socket timeout reached");
                continue;
            }

            recv_multipart(sock, std::back_inserter(msgs));
            if (msgs.size() == 5) { //todo: make this cleaner
                has_proxy = 1;
            } else if (msgs.size() == 4) {
                has_proxy = 0;
            }
            if (msgs.size() != 4+has_proxy)
                Rf_error("unexpected message format");

            cur = msg2str(msgs[0+has_proxy]);
            auto &w = peers[cur];
            w.status = msg2wlife_t(msgs[2+has_proxy]);
            w.call = R_NilValue;
            if (w.status != wlife_t::shutdown)
                break;

            on_shutdown.push_back(msg2r(msgs[3+has_proxy], true));
            send(R_NilValue, false);
            peers.erase(cur);
            msgs.clear();
            if (peers.size() <= has_proxy)
                break;
        };

        return msgs;
    }
};
