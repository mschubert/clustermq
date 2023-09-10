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
        env.clear();

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

        int data_offset;
        std::vector<zmq::message_t> msgs;

        do {
            timeout = poll(timeout);

            msgs.clear();
            auto n = recv_multipart(sock, std::back_inserter(msgs));
            data_offset = register_peer(msgs);
        } while(data_offset >= msgs.size() && peers.size() != 0);

        return msg2r(msgs[data_offset], true);
    }

    void send(SEXP cmd) {
        auto &w = peers[cur];
        bool is_proxied = ! w.via.empty();
        std::set<std::string> new_env;
        std::set_difference(env_names.begin(), env_names.end(), w.env.begin(), w.env.end(),
                std::inserter(new_env, new_env.end()));
        std::vector<std::string> proxy_add_env;
        std::set<std::string> *via_env;

        zmq::multipart_t mp;
        if (is_proxied) {
            via_env = &peers[w.via].env;
            mp.push_back(zmq::message_t(w.via));
        }
        mp.push_back(zmq::message_t(cur));
        mp.push_back(zmq::message_t(0));
        mp.push_back(int2msg(wlife_t::active));
        mp.push_back(r2msg(cmd));

        for (auto &str : new_env) {
            w.env.insert(str);
            if (is_proxied) {
                if (via_env->find(str) != via_env->end())
                    proxy_add_env.push_back(str);
                else
                    via_env->insert(str);
            }
            mp.push_back(zmq::message_t(str));
            zmq::message_t msg;
            msg.copy(env[str]);
            mp.push_back(std::move(msg));
        }

        if (is_proxied) {
            SEXP from_proxy = Rcpp::wrap(proxy_add_env);
            mp.push_back(r2msg(from_proxy));
        }

        w.call = cmd;
        mp.send(sock);
    }
    void send_shutdown() {
        auto &w = peers[cur];

        zmq::multipart_t mp;
        if (!w.via.empty())
            mp.push_back(zmq::message_t(w.via));
        mp.push_back(zmq::message_t(cur));
        mp.push_back(zmq::message_t(0));
        mp.push_back(int2msg(wlife_t::shutdown));

        w.call = R_NilValue;
        w.status = wlife_t::shutdown;
        mp.send(sock);
    }

    void proxy_submit_cmd(SEXP args, int timeout=10000) {
        poll(timeout);
        std::vector<zmq::message_t> msgs;
        auto n = recv_multipart(sock, std::back_inserter(msgs));
        register_peer(msgs);
        // msgs[0] == "proxy" routing id
        // msgs[1] == delimiter
        // msgs[2] == wlife_t::proxy_cmd

        zmq::multipart_t mp;
        mp.push_back(zmq::message_t(cur));
        mp.push_back(zmq::message_t(0));
        mp.push_back(int2msg(wlife_t::proxy_cmd));
        mp.push_back(r2msg(args));
        mp.send(sock);
    }

    void add_env(std::string name, SEXP obj) {
        for (auto &w : peers)
            w.second.env.erase(name);
        env_names.insert(name);
        env[name] = r2msg(R_serialize(obj, R_NilValue));
    }
    void add_pkg(Rcpp::CharacterVector pkg) {
        add_env("package:" + Rcpp::as<std::string>(pkg), pkg);
    }
    Rcpp::DataFrame list_env() {
        std::vector<std::string> names;
        names.reserve(env.size());
        std::vector<int> sizes;
        sizes.reserve(env.size());
        for (const auto &kv: env) {
            names.push_back(kv.first);
            sizes.push_back(kv.second.size());
        }
        return Rcpp::DataFrame::create(Rcpp::_["object"] = Rcpp::wrap(names),
                Rcpp::_["size"] = Rcpp::wrap(sizes));
    }

    Rcpp::List list_workers() {
        std::vector<std::string> names;
        names.reserve(peers.size());
        std::vector<int> status;
        status.reserve(peers.size());
        Rcpp::List wtime, mem;
        for (const auto &kv: peers) {
            names.push_back(kv.first);
            status.push_back(kv.second.status);
            wtime.push_back(kv.second.time);
            mem.push_back(kv.second.mem);
        }
        return Rcpp::List::create(
            Rcpp::_["worker"] = Rcpp::wrap(names),
            Rcpp::_["status"] = Rcpp::wrap(status),
            Rcpp::_["time"] = wtime,
            Rcpp::_["mem"] = mem
        );
    }

private:
    struct worker_t {
        std::set<std::string> env;
        SEXP call {R_NilValue};
        SEXP time {Rcpp::List()};
        SEXP mem {Rcpp::List()};
        wlife_t status;
        std::string via;
    };

    zmq::context_t *ctx {nullptr};
    int has_proxy {0};
    zmq::socket_t sock;
    std::string cur;
    std::unordered_map<std::string, worker_t> peers;
    std::unordered_map<std::string, zmq::message_t> env;
    std::set<std::string> env_names;

    int poll(int timeout=-1) {
        auto pitems = std::vector<zmq::pollitem_t>(1);
        pitems[0].socket = sock;
        pitems[0].events = ZMQ_POLLIN;

        auto time_ms = std::chrono::milliseconds(timeout);
        auto time_left = time_ms;
        auto start = Time::now();

        int rc = 0;
        do {
            try {
                rc = zmq::poll(pitems, time_left);
            } catch (zmq::error_t const &e) {
                if (errno != EINTR || pending_interrupt())
                    Rf_error(e.what());
            }

            if (timeout != -1) {
                auto ms_diff = std::chrono::duration_cast<ms>(Time::now() - start);
                time_left = time_ms - ms_diff;
                timeout = time_left.count();
                if (timeout < 0) {
                    std::ostringstream err;
                    err << "Socket timed out after " << ms_diff.count() << " ms\n";
                    throw Rcpp::exception(err.str().c_str());
                }
            }
        } while (rc == 0);

        return timeout;
    }

    int register_peer(std::vector<zmq::message_t> &msgs) {
//        std::cout << "Received message: ";
//        for (int i=0; i<msgs.size(); i++)
//            std::cout << msgs[i].size() << " ";
//        std::cout << "\n";

        int cur_i = 0;
        if (msgs[1].size() != 0)
            ++cur_i;

        cur = msgs[cur_i].to_string();
        auto &w = peers[cur];
        w.call = R_NilValue;
        if (cur_i == 1)
            w.via = msgs[0].to_string();

        if (msgs[++cur_i].size() != 0)
            Rf_error("No frame delimiter found at expected position");

        // handle status frame if present, else it's a disconnect notification
        if (msgs.size() > ++cur_i)
            w.status = msg2wlife_t(msgs[cur_i]);
        else {
            if (w.status == wlife_t::proxy_cmd) {
                auto it = peers.begin();
                while (it != peers.end()) {
                    if (it->second.via == cur) {
                        if (it->second.status == wlife_t::shutdown)
                            it = peers.erase(it);
                        else
                            Rf_error("Proxy disconnect with active worker(s)");
                    }
                }
                peers.erase(cur);
            } else if (w.status == wlife_t::shutdown)
                peers.erase(cur);
            else
                Rf_error("Unexpected worker disconnect");
        }

        w.time = msg2r(msgs[++cur_i], true);
        w.mem = msg2r(msgs[++cur_i], true);
        return ++cur_i;
    }
};
