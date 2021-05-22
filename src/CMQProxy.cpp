#include <Rcpp.h>
#include "CMQProxy.h"

RCPP_MODULE(cmq_proxy) {
    using namespace Rcpp;
    class_<CMQMaster>("CMQProxy")
        .constructor()
//        .constructor<zmq::context_t*>()
//        .method("main_loop", &CMQMaster::main_loop)
//        .method("listen", &CMQMaster::listen)
    ;
}
