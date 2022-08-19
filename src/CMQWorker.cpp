#include <Rcpp.h>
#include "CMQWorker.h"

RCPP_MODULE(cmq_worker) {
    using namespace Rcpp;
    class_<CMQWorker>("CMQWorker")
        .constructor()
        .method("connect", &CMQWorker::connect)
        .method("process_one", &CMQWorker::process_one)
    ;
}
