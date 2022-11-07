#include <Rcpp.h>
#include "CMQMaster.h"

RCPP_MODULE(cmq_master) {
    using namespace Rcpp;
    class_<CMQMaster>("CMQMaster")
        .constructor()
        .constructor<SEXP>()
        .method("listen", &CMQMaster::listen)
        .method("close", &CMQMaster::close)
        .method("recv", &CMQMaster::recv)
        .method("send", &CMQMaster::send)
        .method("add_env", &CMQMaster::add_env)
        .method("add_pkg", &CMQMaster::add_pkg)
    ;
}
