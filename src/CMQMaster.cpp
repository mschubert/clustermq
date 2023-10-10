#include <Rcpp.h>
#include "CMQMaster.h"

RCPP_MODULE(cmq_master) {
    using namespace Rcpp;
    class_<CMQMaster>("CMQMaster")
        .constructor()
        .method("context", &CMQMaster::context)
        .method("listen", &CMQMaster::listen)
        .method("close", &CMQMaster::close)
        .method("recv", &CMQMaster::recv)
        .method("send", &CMQMaster::send)
        .method("send_shutdown", &CMQMaster::send_shutdown)
        .method("proxy_submit_cmd", &CMQMaster::proxy_submit_cmd)
        .method("add_env", &CMQMaster::add_env)
        .method("add_pkg", &CMQMaster::add_pkg)
        .method("list_env", &CMQMaster::list_env)
        .method("add_pending_workers", &CMQMaster::add_pending_workers)
        .method("list_workers", &CMQMaster::list_workers)
    ;
}
