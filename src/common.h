#ifndef _COMMON_H_
#define _COMMON_H_

#include <Rcpp.h>
#include <chrono>
#include <string>
#include <thread>
#include <unordered_map>
#include "zmq.hpp"
#include "zmq_addon.hpp"

enum wlife_t {
    active,
    shutdown,
    error,
    proxy_cmd,
    proxy_error
};
typedef std::chrono::high_resolution_clock Time;
typedef std::chrono::milliseconds ms;
extern Rcpp::Function R_serialize;
extern Rcpp::Function R_unserialize;

void check_interrupt_fn(void *dummy);
int pending_interrupt();
zmq::message_t int2msg(int val);
zmq::message_t r2msg(SEXP data);
SEXP msg2r(zmq::message_t &msg, bool unserialize);
wlife_t msg2wlife_t(zmq::message_t &msg);

#endif // _COMMON_H_
