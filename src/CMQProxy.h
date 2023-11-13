#include <Rcpp.h>
#include "common.h"
#include "CMQMaster.h"

class CMQProxy {
public:
    CMQProxy(): ctx(new zmq::context_t(1)) {
        external_context = false;
    }
    CMQProxy(SEXP ctx_): ctx(Rcpp::as<Rcpp::XPtr<zmq::context_t>>(ctx_)) {}
    ~CMQProxy() { close(); }

    void close(int timeout=1000L) {
        if (mon.handle() != nullptr) {
            mon.set(zmq::sockopt::linger, 0);
            mon.close();
        }
        if (to_worker.handle() != nullptr) {
            to_worker.set(zmq::sockopt::linger, timeout);
            to_worker.close();
        }
        if (to_master.handle() != nullptr) {
            to_master.set(zmq::sockopt::linger, timeout);
            to_master.close();
        }
        if (!external_context && ctx != nullptr) {
            ctx->close();
            delete ctx;
            ctx = nullptr;
        }
    }

    void connect(std::string addr, int timeout=-1) {
        to_master = zmq::socket_t(*ctx, ZMQ_DEALER);
        to_master.set(zmq::sockopt::connect_timeout, timeout);
        to_master.set(zmq::sockopt::routing_id, "proxy");

        if (zmq_socket_monitor(to_master, "inproc://monitor", ZMQ_EVENT_DISCONNECTED) < 0)
            Rcpp::stop("failed to create socket monitor");
        mon = zmq::socket_t(*ctx, ZMQ_PAIR);
        mon.connect("inproc://monitor");

        to_master.connect(addr);
    }

    void proxy_request_cmd() {
        to_master.send(zmq::message_t(0), zmq::send_flags::sndmore);
        to_master.send(int2msg(wlife_t::proxy_cmd), zmq::send_flags::sndmore);
        to_master.send(r2msg(proc_time()), zmq::send_flags::sndmore);
        to_master.send(r2msg(gc()), zmq::send_flags::none);
    }
    SEXP proxy_receive_cmd() {
        std::vector<zmq::message_t> msgs;
        auto n = recv_multipart(to_master, std::back_inserter(msgs));
        auto status = msg2wlife_t(msgs[1]);
        return msg2r(msgs[2], true);
    }

    std::string listen(Rcpp::CharacterVector addrs) {
        to_worker = zmq::socket_t(*ctx, ZMQ_ROUTER);
        to_worker.set(zmq::sockopt::router_mandatory, 1);
        #ifdef ZMQ_BUILD_DRAFT_API
        to_worker.set(zmq::sockopt::router_notify, ZMQ_NOTIFY_DISCONNECT);
        #endif

        int i;
        for (i=0; i<addrs.length(); i++) {
            auto addr = Rcpp::as<std::string>(addrs[i]);
            try {
                to_worker.bind(addr);
                return to_worker.get(zmq::sockopt::last_endpoint);
            } catch(zmq::error_t const &e) {
                if (errno != EADDRINUSE)
                    Rcpp::stop(e.what());
            }
        }
        Rcpp::stop("Could not bind port to any address in provided pool");
    }

    bool process_one() {
        auto pitems = std::vector<zmq::pollitem_t>(3);
        pitems[0].socket = to_master;
        pitems[0].events = ZMQ_POLLIN;
        pitems[1].socket = to_worker;
        pitems[1].events = ZMQ_POLLIN;
        pitems[2].socket = mon;
        pitems[2].events = ZMQ_POLLIN;

        auto time_left = std::chrono::milliseconds(-1);
        int rc = 0;
        do {
            try {
                rc = zmq::poll(pitems, time_left);
            } catch (zmq::error_t const &e) {
                if (errno != EINTR || pending_interrupt())
                    Rcpp::stop(e.what());
            }
        } while (rc == 0);

        // master to worker communication -> add R env objects
        // frames: id, delim, status, call, [objs{1..n},] env_add
        if (pitems[0].revents > 0) {
            std::vector<zmq::message_t> msgs;
            auto n = recv_multipart(to_master, std::back_inserter(msgs));
            std::vector<std::string> add_from_proxy;
            if (msgs.size() >= 5) {
                add_from_proxy = Rcpp::as<std::vector<std::string>>(msg2r(msgs.back(), true));
                msgs.pop_back();
            }

            zmq::multipart_t mp;
            for (int i=0; i<msgs.size(); i++) {
                zmq::message_t msg;
                msg.copy(msgs[i]);
                mp.push_back(std::move(msg));
                if (i >= 4) {
                    std::string name = msg.to_string();
                    zmq::message_t store, fwd;
                    store.copy(msgs[++i]);
                    fwd.copy(store);
                    mp.push_back(std::move(fwd));
                    env[name] = std::move(store);
                }
            }

            for (auto &name : add_from_proxy) {
                zmq::message_t add;
                add.copy(env[name]);
                mp.push_back(std::move(add));
            }

            mp.send(to_worker);
        }

        // worker to master communication -> simple forward
        if (pitems[1].revents > 0) {
            std::vector<zmq::message_t> msgs;
            auto n = recv_multipart(to_worker, std::back_inserter(msgs));
            zmq::multipart_t mp;
            for (int i=0; i<msgs.size(); i++) {
                zmq::message_t msg;
                msg.move(msgs[i]);
                mp.push_back(std::move(msg));
            }
            mp.send(to_master);
        }

        if (pitems[2].revents > 0)
            return false;

        return true;
    }

private:
    Rcpp::Function proc_time {"proc.time"};
    Rcpp::Function gc {"gc"};
    bool external_context {true};
    zmq::context_t *ctx {nullptr};
    zmq::socket_t to_master;
    zmq::socket_t to_worker;
    zmq::socket_t mon;
    std::unordered_map<std::string, zmq::message_t> env;
};
