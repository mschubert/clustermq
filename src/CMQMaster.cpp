#include <Rcpp.h>
#include "CMQMaster.h"

RCPP_MODULE(cmq_master) {
    using namespace Rcpp;
    class_<CMQMaster>("CMQMaster")
        .constructor()
//        .constructor<zmq::context_t*>()
        .method("main_loop", &CMQMaster::main_loop)
        .method("listen", &CMQMaster::listen)
        .method("send_work", &CMQMaster::send_work)
        .method("send_shutdown", &CMQMaster::send_shutdown)
        .method("poll_recv", &CMQMaster::poll_recv)
    ;
}
