#include <Rcpp.h>
#include "CMQMaster.h"

RCPP_MODULE(cmq_master) {
    using namespace Rcpp;
    class_<CMQMaster>("CMQMaster")
        .constructor()
//        .constructor<zmq::context_t*>()
        .method("listen", &CMQMaster::listen)
        .method("recv", &CMQMaster::recv)
        .method("send", &CMQMaster::send)
        .method("add_env", &CMQMaster::add_env)
    ;
}
