#include <Rcpp.h>
#include "CMQMaster.h"

RCPP_MODULE(cmq_master) {
    using namespace Rcpp;
    class_<CMQMaster>("CMQMaster")
        .constructor()
//        .constructor<zmq::context_t*>()
        .method("listen", &CMQMaster::listen)
        .method("recv_one", &CMQMaster::recv_one)
        .method("send_one", &CMQMaster::send_one)
        .method("add_env", &CMQMaster::add_env)
    ;
}
