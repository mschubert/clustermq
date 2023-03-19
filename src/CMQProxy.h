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

    void close(int timeout=0) {
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
        to_master = zmq::socket_t(*ctx, ZMQ_REQ);
        to_master.set(zmq::sockopt::connect_timeout, timeout);
        //todo: add socket monitor like in CMQWorker.h@connect
        to_master.connect(addr);
        // send proxy_up to master (don't do this yet, just submit 1 multicore worker @R level)
    }

    std::string listen(Rcpp::CharacterVector addrs) {
        to_worker = zmq::socket_t(*ctx, ZMQ_REP);

        int i;
        for (i=0; i<addrs.length(); i++) {
            auto addr = Rcpp::as<std::string>(addrs[i]);
            try {
                to_worker.bind(addr);
                return to_worker.get(zmq::sockopt::last_endpoint);
            } catch(zmq::error_t const &e) {
                if (errno != EADDRINUSE)
                    Rf_error(e.what());
            }
        }
        Rf_error("Could not bind port to any address in provided pool");
    }

    void process_one() {
        auto pitems = std::vector<zmq::pollitem_t>(2);
        pitems[0].socket = to_master;
        pitems[0].events = ZMQ_POLLIN;
        pitems[1].socket = to_worker;
        pitems[1].events = ZMQ_POLLIN;

        auto time_ms = std::chrono::milliseconds(-1);
        try {
            zmq::poll(pitems, time_ms);
        } catch (zmq::error_t const &e) {
            if (errno != EINTR || pending_interrupt())
                Rf_error(e.what());
        }

        if (pitems[0].revents > 0) {
            // master event, foward to worker
            zmq::multipart_t mp(to_master);
            mp.send(to_worker);
        }
        if (pitems[1].revents > 0) {
            // worker event, forward to master
            zmq::multipart_t mp(to_worker); // https://github.com/zeromq/cppzmq/blob/master/zmq_addon.hpp#L334
            mp.send(to_master);
        }
    }

private:
    bool external_context {true};
    zmq::context_t *ctx {nullptr};
    zmq::socket_t to_master;
    zmq::socket_t to_worker;
};
