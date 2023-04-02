#include <Rcpp.h>
#include "CMQProxy.h"

RCPP_MODULE(cmq_proxy) {
    using namespace Rcpp;
    class_<CMQProxy>("CMQProxy")
        .constructor()
        .constructor<SEXP>()
        .method("listen", &CMQProxy::listen)
        .method("connect", &CMQProxy::connect)
        .method("proxy_request_cmd", &CMQProxy::proxy_request_cmd)
        .method("proxy_receive_cmd", &CMQProxy::proxy_receive_cmd)
        .method("close", &CMQProxy::close)
        .method("process_one", &CMQProxy::process_one)
    ;
}
