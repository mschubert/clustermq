#include <Rcpp.h>
#include "common.h"

class CMQMaster {
public:
    CMQMaster(): ctx(new zmq::context_t(3)) {}
    ~CMQMaster() { close(); }

    SEXP context() const {
        Rcpp::XPtr<zmq::context_t> p(ctx, true);
        return p;
    }

    std::string listen(Rcpp::CharacterVector addrs) {
        sock = zmq::socket_t(*ctx, ZMQ_ROUTER);
        sock.set(zmq::sockopt::router_mandatory, 1);
        #ifdef ZMQ_BUILD_DRAFT_API
        sock.set(zmq::sockopt::router_notify, ZMQ_NOTIFY_DISCONNECT);
        #endif

        int i;
        for (i=0; i<addrs.length(); i++) {
            auto addr = Rcpp::as<std::string>(addrs[i]);
            try {
                sock.bind(addr);
                return sock.get(zmq::sockopt::last_endpoint);
            } catch(zmq::error_t const &e) {
                if (errno != EADDRINUSE)
                    Rcpp::stop(std::string("Binding port failed (") + e.what() + ")");
            }
        }
        Rcpp::stop("Could not bind port to any address in provided pool");
    }

    void close(int timeout=0) {
        peers.clear();
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
        int data_offset;
        std::vector<zmq::message_t> msgs;

        do {
            int w_active = pending_workers;
            for (const auto &kv: peers) {
                if (kv.second.status == wlife_t::active || kv.second.status == wlife_t::proxy_cmd)
                    w_active++;
            }
            if (w_active <= 0)
                Rcpp::stop("Trying to receive data without workers");

            msgs.clear();
            timeout = poll(timeout);
            auto n = recv_multipart(sock, std::back_inserter(msgs));
            data_offset = register_peer(msgs);
        } while(data_offset >= msgs.size());

        return msg2r(msgs[data_offset], true);
    }

    void send(SEXP cmd) {
        if (peers.find(cur) == peers.end())
            Rcpp::stop("Trying to send to worker that does not exist");
        auto &w = peers[cur];
        if (w.status != wlife_t::active)
            Rcpp::stop("Trying to send to worker that is not active");
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
                if (via_env->find(str) != via_env->end()) {
//                    std::cout << "+from_proxy " << str << "\n";
                    proxy_add_env.push_back(str);
                    continue;
                } else {
//                    std::cout << "+from_master " << str << "\n";
                    via_env->insert(str);
                }
            }
            mp.push_back(zmq::message_t(str));
            mp.push_back(zmq::message_t(env[str].data(), env[str].size()));
        }

        if (is_proxied)
            mp.push_back(r2msg(Rcpp::wrap(proxy_add_env)));

        w.call = cmd;
        mp.send(sock);
    }
    void send_shutdown() {
        if (peers.find(cur) == peers.end())
            Rcpp::stop("Trying to send to worker that does not exist");
        auto &w = peers[cur];
        if (w.status != wlife_t::active)
            Rcpp::stop("Trying to send to worker that is not active");

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
    Rcpp::DataFrame list_env() const {
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

    void add_pending_workers(int n) {
        pending_workers += n;
    }

    Rcpp::List list_workers() const {
        std::vector<std::string> names, status;
        std::vector<int> calls;
        names.reserve(peers.size());
        status.reserve(peers.size());
        calls.reserve(peers.size());
        Rcpp::List wtime, mem;
        std::string cur_hex;
        for (const auto &kv: peers) {
            std::stringstream os;
            os << std::hex << std::setw(2) << std::setfill('0');
            for (const auto &ch: kv.first)
                os << static_cast<short>(ch);
            names.push_back(os.str());
            if (kv.first == cur)
                cur_hex = os.str();
            status.push_back(std::string(wlife_t2str(kv.second.status)));
            calls.push_back(kv.second.n_calls);
            wtime.push_back(kv.second.time);
            mem.push_back(kv.second.mem);
        }
        return Rcpp::List::create(
            Rcpp::_["worker"] = Rcpp::wrap(names),
            Rcpp::_["status"] = Rcpp::wrap(status),
            Rcpp::_["current"] = cur_hex,
            Rcpp::_["calls"] = calls,
            Rcpp::_["time"] = wtime,
            Rcpp::_["mem"] = mem,
            Rcpp::_["pending"] = pending_workers
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
        int n_calls {-1};
    };

    zmq::context_t *ctx {nullptr};
    int pending_workers {0};
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
                    Rcpp::stop(e.what());
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
        int prev_size = peers.size();
        auto &w = peers[cur];
        pending_workers -= peers.size() - prev_size;
//        if (pending_workers < 0)
//            Rcpp::stop("More workers registered than expected");
        w.call = R_NilValue;
        if (cur_i == 1)
            w.via = msgs[0].to_string();

        if (msgs[++cur_i].size() != 0)
            Rcpp::stop("No frame delimiter found at expected position");

        // handle status frame if present, else it's a disconnect notification
        if (msgs.size() > ++cur_i) {
            w.status = msg2wlife_t(msgs[cur_i]);
            w.n_calls++;
        } else {
            if (w.status == wlife_t::proxy_cmd) {
                auto it = peers.begin();
                while (it != peers.end()) {
                    if (it->second.via == cur) {
                        if (it->second.status == wlife_t::shutdown)
                            it = peers.erase(it);
                        else
                            Rcpp::stop("Proxy disconnect with active worker(s)");
                    }
                }
                peers.erase(cur);
            } else if (w.status == wlife_t::shutdown) {
                peers.erase(cur);
            } else
                Rcpp::stop("Unexpected worker disconnect");
        }

        if (msgs.size() > cur_i+2) {
            w.time = msg2r(msgs[++cur_i], true);
            w.mem = msg2r(msgs[++cur_i], true);
        }
        return ++cur_i;
    }
};
