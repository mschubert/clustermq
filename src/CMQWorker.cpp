#include <Rcpp.h>
#include "CMQWorker.h"

RCPP_MODULE(cmq_worker) {
    using namespace Rcpp;
    void (CMQWorker::*send_1)(SEXP) = &CMQWorker::send ;
    void (CMQWorker::*send_2)(SEXP, bool) = &CMQWorker::send ;
    class_<CMQWorker>("CMQWorker")
        .constructor<std::string>()
        .method("main_loop", &CMQWorker::main_loop)
        .method("get_data_redirect", &CMQWorker::get_data_redirect)
        .method("send", send_1)
        .method("send", send_2)
        .method("receive", &CMQWorker::receive)
    ;
}
