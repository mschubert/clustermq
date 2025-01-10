#ifndef _COMMON_H_
#define _COMMON_H_

#include <Rcpp.h>
#include <chrono>
#include <string>
#include <thread>
#include <unordered_map>
#include "zmq.hpp"
#include "zmq_addon.hpp"

#if ! ZMQ_VERSION >= ZMQ_MAKE_VERSION(4, 3, 0) || \
    ! CPPZMQ_VERSION >= ZMQ_MAKE_VERSION(4, 10, 0)
#define XSTR(x) STR(x)
#define STR(x) #x
#pragma message "libzmq version is: " XSTR(ZMQ_VERSION_MAJOR) "." \
    XSTR(ZMQ_VERSION_MINOR) "." XSTR(ZMQ_VERSION_PATCH)
#pragma message "cppzmq version is: " XSTR(CPPZMQ_VERSION_MAJOR) "." \
    XSTR(CPPZMQ_VERSION_MINOR) "." XSTR(CPPZMQ_VERSION_PATCH)
#error clustermq needs libzmq>=4.3.0 and cppzmq>=4.10.0
#endif

enum wlife_t {
    active,
    shutdown,
    finished,
    error,
    proxy_cmd,
    proxy_error
};
const char* wlife_t2str(wlife_t status);
typedef std::chrono::high_resolution_clock Time;
typedef std::chrono::milliseconds ms;
extern Rcpp::Function R_serialize;
extern Rcpp::Function R_unserialize;

void check_interrupt_fn(void *dummy);
int pending_interrupt();
zmq::message_t int2msg(const int val);
zmq::message_t r2msg(SEXP data);
SEXP msg2r(const zmq::message_t &&msg, const bool unserialize);
wlife_t msg2wlife_t(const zmq::message_t &msg);
std::string z85_encode_routing_id(const std::string rid);
std::set<std::string> set_difference(std::set<std::string> &set1, std::set<std::string> &set2);

#endif // _COMMON_H_
