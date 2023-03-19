#include <Rcpp.h>
#include "CMQProxy.h"

RCPP_MODULE(cmq_proxy) {
    using namespace Rcpp;
    class_<CMQProxy>("CMQProxy")
        .constructor()
        .constructor<SEXP>()
        .method("listen", &CMQProxy::listen)
        .method("connect", &CMQProxy::connect)
        .method("close", &CMQProxy::close)
        .method("process_one", &CMQProxy::process_one)
    ;
}
