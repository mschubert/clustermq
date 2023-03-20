#include <Rcpp.h>
#include "CMQMaster.h"

RCPP_MODULE(cmq_master) {
    using namespace Rcpp;
    class_<CMQMaster>("CMQMaster")
        .constructor()
        .method("context", &CMQMaster::context)
        .method("listen", &CMQMaster::listen)
        .method("cleanup", &CMQMaster::cleanup)
        .method("close", &CMQMaster::close)
        .method("recv", &CMQMaster::recv)
        .method("send", &CMQMaster::send)
        .method("add_env", &CMQMaster::add_env)
        .method("add_pkg", &CMQMaster::add_pkg)
        .method("proxy_submit_cmd", &CMQMaster::proxy_submit_cmd)
    ;
}
