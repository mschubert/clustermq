#include <Rcpp.h>
#include "CMQWorker.h"

RCPP_MODULE(cmq_worker) {
    using namespace Rcpp;
    class_<CMQWorker>("CMQWorker")
        .constructor()
        .constructor<SEXP>()
        .method("connect", &CMQWorker::connect)
        .method("close", &CMQWorker::close)
        .method("poll", &CMQWorker::poll)
        .method("process_one", &CMQWorker::process_one)
    ;
}
