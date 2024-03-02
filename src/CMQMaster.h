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
                if ((errno != EADDRINUSE && errno != EINTR) || pending_interrupt())
                    Rcpp::stop(std::string("Binding port failed (") + e.what() + ")");
            }
        }
        Rcpp::stop("Could not bind port to any address in provided pool");
    }

    bool close(int timeout=1000) {
        if (ctx == nullptr)
            return is_cleaned_up;

        auto pitems = std::vector<zmq::pollitem_t>(1);
        pitems[0].socket = sock;
        pitems[0].events = ZMQ_POLLIN;

        auto time_ms = std::chrono::milliseconds(timeout);
        auto time_left = time_ms;
        auto start = Time::now();
        while (time_left.count() > 0) {
            if (std::find_if(peers.begin(), peers.end(), [](const std::pair<const std::string, worker_t> &w) { // 'const auto &w' is C++14
                        return w.second.status == wlife_t::active; }) == peers.end()) {
                is_cleaned_up = true;
                break;
            }

            if (peers.find(cur) != peers.end()) {
                auto &w = peers[cur];
                if (w.status == wlife_t::active && w.call == R_NilValue)
                    try {
                        send_shutdown();
                    } catch (...) {}
            }

            try {
                int rc = zmq::poll(pitems, time_left);
                if (pitems[0].revents) {
                    std::vector<zmq::message_t> msgs;
                    auto n = recv_multipart(sock, std::back_inserter(msgs));
                    register_peer(msgs);
                }
            } catch (zmq::error_t const &e) {
                if (errno != EINTR || pending_interrupt())
                    throw;
            } catch (...) {
                timeout = 0;
                break;
            }
            time_left = time_ms - std::chrono::duration_cast<ms>(Time::now() - start);
        };

        env.clear();
        pending_workers = 0;

        if (sock.handle() != nullptr) {
            sock.set(zmq::sockopt::linger, timeout);
            sock.close();
        }
        if (ctx != nullptr) {
            ctx->close();
            ctx = nullptr;
        }
        return is_cleaned_up;
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

        return msg2r(std::move(msgs[data_offset]), true);
    }

    int send(SEXP cmd) {
        auto &w = check_current_worker(wlife_t::active);
        std::set<std::string> new_env;
        std::set_difference(env_names.begin(), env_names.end(), w.env.begin(), w.env.end(),
                std::inserter(new_env, new_env.end()));
        auto mp = init_multipart(w, wlife_t::active);
        mp.push_back(r2msg(cmd));

        if (w.via.empty()) {
            for (auto &str : new_env) {
                w.env.insert(str);
                mp.push_back(zmq::message_t(str));
                mp.push_back(zmq::message_t(env[str].data(), env[str].size()));
            }
        } else {
            std::vector<std::string> proxy_add_env;
            auto &via_env = peers[w.via].env;
            for (auto &str : new_env) {
                w.env.insert(str);
                if (via_env.find(str) == via_env.end()) {
//                    std::cout << "+from_master " << str << "\n";
                    via_env.insert(str);
                    mp.push_back(zmq::message_t(str));
                    mp.push_back(zmq::message_t(env[str].data(), env[str].size()));
                } else {
//                    std::cout << "+from_proxy " << str << "\n";
                    proxy_add_env.push_back(str);
                }
            }
            mp.push_back(r2msg(Rcpp::wrap(proxy_add_env)));
        }

        w.call = cmd;
        w.call_ref = ++call_counter;
        mp.send(sock);
        return w.call_ref;
    }
    void send_shutdown() {
        auto &w = check_current_worker(wlife_t::active);
        auto mp = init_multipart(w, wlife_t::shutdown);
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

        auto &w = check_current_worker(wlife_t::proxy_cmd);
        auto mp = init_multipart(w, wlife_t::proxy_cmd);
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
        std::string cur_z85;
        for (const auto &kv: peers) {
            if (kv.second.status == wlife_t::proxy_cmd || kv.second.status == wlife_t::error)
                continue;
            names.push_back(z85_encode_routing_id(kv.first));
            if (kv.first == cur)
                cur_z85 = names.back();
            status.push_back(std::string(wlife_t2str(kv.second.status)));
            calls.push_back(kv.second.n_calls);
            wtime.push_back(kv.second.time);
            mem.push_back(kv.second.mem);
        }
        return Rcpp::List::create(
            Rcpp::_["worker"] = Rcpp::wrap(names),
            Rcpp::_["status"] = Rcpp::wrap(status),
            Rcpp::_["current"] = cur_z85,
            Rcpp::_["calls"] = calls,
            Rcpp::_["time"] = wtime,
            Rcpp::_["mem"] = mem,
            Rcpp::_["pending"] = pending_workers
        );
    }
    Rcpp::List current() {
        if (peers.find(cur) == peers.end())
            return Rcpp::List::create();
        const auto &w = peers[cur];
        return Rcpp::List::create(
            Rcpp::_["worker"] = z85_encode_routing_id(cur),
            Rcpp::_["status"] = Rcpp::wrap(wlife_t2str(w.status)),
            Rcpp::_["call_ref"] = w.call_ref,
            Rcpp::_["calls"] = w.n_calls,
            Rcpp::_["time"] = w.time,
            Rcpp::_["mem"] = w.mem
        );
    }
    int workers_running() {
        return std::count_if(peers.begin(), peers.end(), [](const std::pair<std::string, worker_t> &w) { // 'const auto &w' is C++14
                return w.second.status == wlife_t::active; });
    }
    int workers_total() {
        return workers_running() + pending_workers;
    }

private:
    struct worker_t {
        std::set<std::string> env;
        Rcpp::RObject call {R_NilValue};
        Rcpp::RObject time {R_NilValue};
        Rcpp::RObject mem {R_NilValue};
        wlife_t status;
        std::string via;
        int n_calls {-1};
        int call_ref {-1};
    };

    zmq::context_t *ctx {nullptr};
    bool is_cleaned_up {false};
    int pending_workers {0};
    int call_counter {-1};
    zmq::socket_t sock;
    std::string cur;
    std::unordered_map<std::string, worker_t> peers;
    std::unordered_map<std::string, zmq::message_t> env;
    std::set<std::string> env_names;

    worker_t &check_current_worker(const wlife_t status) {
        if (peers.find(cur) == peers.end())
            Rcpp::stop("Trying to send to worker that does not exist");
        auto &w = peers[cur];
        if (w.status != status)
            Rcpp::stop("Trying to send to worker with invalid status");
        return w;
    }
    zmq::multipart_t init_multipart(const worker_t &w, const wlife_t status) const {
        zmq::multipart_t mp;
        if (!w.via.empty())
            mp.push_back(zmq::message_t(w.via));
        mp.push_back(zmq::message_t(cur));
        mp.push_back(zmq::message_t(0));
        mp.push_back(int2msg(status));
        return mp;
    }

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
                for (const auto &w: peers) {
                    if (w.second.via == cur && w.second.status == wlife_t::active)
                        Rcpp::stop("Proxy disconnect with active worker(s)");
                }
            } else if (w.status == wlife_t::shutdown) {
                w.status = wlife_t::finished;
            } else
                Rcpp::stop("Unexpected worker disconnect");
        }

        if (peers.size() > prev_size && w.status == wlife_t::active) {
            if (--pending_workers < 0)
                Rcpp::stop("More workers registered than expected");
        }

        if (msgs.size() > cur_i+2) {
            w.time = msg2r(std::move(msgs[++cur_i]), true);
            w.mem = msg2r(std::move(msgs[++cur_i]), true);
        }
        return ++cur_i;
    }
};
