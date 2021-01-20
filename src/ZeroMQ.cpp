#include "ZeroMQ.hpp"

RCPP_MODULE(zmq) {
    using namespace Rcpp;
    class_<ZeroMQ>("ZeroMQ_raw")
        .constructor() // .constructor<int>() SIGABRT
        .method("listen", &ZeroMQ::listen)
        .method("connect", &ZeroMQ::connect)
        .method("disconnect", &ZeroMQ::disconnect)
        .method("send", &ZeroMQ::send)
        .method("receive", &ZeroMQ::receive)
        .method("poll", &ZeroMQ::poll)
    ;
}
