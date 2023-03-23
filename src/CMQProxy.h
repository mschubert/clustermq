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
        //todo: add socket monitor like in CMQWorker.h@connect
        to_master.connect(addr);
    }

    void proxy_request_cmd() {
        to_master.send(zmq::message_t(0), zmq::send_flags::sndmore);
        to_master.send(int2msg(wlife_t::proxy_cmd), zmq::send_flags::sndmore);
        to_master.send(r2msg(R_NilValue), zmq::send_flags::none);
    }

    SEXP proxy_receive_cmd() {
        std::vector<zmq::message_t> msgs;
        recv_multipart(to_master, std::back_inserter(msgs));
        auto status = msg2wlife_t(msgs[1]);
        return msg2r(msgs[2], true);
    }

    std::string listen(Rcpp::CharacterVector addrs) {
        to_worker = zmq::socket_t(*ctx, ZMQ_ROUTER);
        to_worker.set(zmq::sockopt::router_mandatory, 1);

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

    bool process_one() {
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

        // master to worker communication: add R env objects
        if (pitems[0].revents > 0) {
            std::vector<zmq::message_t> msgs;
            recv_multipart(to_master, std::back_inserter(msgs));
            auto status = msg2wlife_t(msgs[1]);
            if (status == wlife_t::proxy_shutdown)
                return false;
            //todo: cache and add objects
            zmq::multipart_t mp;
            for (int i=0; i<msgs.size(); i++)
                mp.push_back(std::move(msgs[i]));
            mp.send(to_worker);
        }

        // worker to master communication
        if (pitems[1].revents > 0) {
            std::vector<zmq::message_t> msgs;
            recv_multipart(to_worker, std::back_inserter(msgs));
            zmq::multipart_t mp;
            for (int i=0; i<msgs.size(); i++)
                mp.push_back(std::move(msgs[i]));
            mp.send(to_master);
        }
        return true;
    }

private:
    bool external_context {true};
    zmq::context_t *ctx {nullptr};
    zmq::socket_t to_master;
    zmq::socket_t to_worker;
};
