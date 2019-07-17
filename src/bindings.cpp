#include <Rcpp.h>
#include <chrono>
#include <string>
#include "zmq.hpp"

typedef std::chrono::high_resolution_clock Time;
typedef std::chrono::milliseconds ms;

Rcpp::Function R_serialize("serialize");
Rcpp::Function R_unserialize("unserialize");

int str2socket(std::string str) {
    if (str == "ZMQ_REP") {
        return ZMQ_REP;
    } else if (str == "ZMQ_REQ") {
        return ZMQ_REQ;
    } else if (str == "ZMQ_XREP") {
        return ZMQ_XREP;
    } else if (str == "ZMQ_XREQ") {
        return ZMQ_XREQ;
    } else {
        Rcpp::exception(("Invalid socket type: " + str).c_str());
    }
    return -1;
}

/* Check for interrupt without long jumping */
void check_interrupt_fn(void *dummy) {
    R_CheckUserInterrupt();
}

int pending_interrupt() {
    return !(R_ToplevelExec(check_interrupt_fn, NULL));
}

// [[Rcpp::export]]
SEXP initContext(int threads=1) {
    auto context = new zmq::context_t(threads);
    Rcpp::XPtr<zmq::context_t> context_(context, true);
    return context_;
}

// [[Rcpp::export]]
SEXP initSocket(SEXP context_, std::string socket_type_) {
    Rcpp::XPtr<zmq::context_t> context(context_);
    auto socket_type = str2socket(socket_type_);
    auto socket = new zmq::socket_t(*context, socket_type);
    Rcpp::XPtr<zmq::socket_t> socket_(socket, true);
    return socket_;
}

// [[Rcpp::export]]
SEXP initMessage(SEXP data_) {
    if (TYPEOF(data_) != RAWSXP) // could serialize + nocopy here
        Rcpp::exception("initMessage expects type RAWSXP");
    auto message = new zmq::message_t(Rf_xlength(data_));
    memcpy(message->data(), RAW(data_), Rf_xlength(data_));
    // no copy below, see first that one copy works
    // zmq::message_t msg(reinterpret_cast<void*>(data_), Rf_xlength(data_), NULL);
    Rcpp::XPtr<zmq::message_t> message_(message, true);
    return message_;
}

// [[Rcpp::export]]
void bindSocket(SEXP socket_, std::string address) {
    Rcpp::XPtr<zmq::socket_t> socket(socket_);
    socket->bind(address);
}

// [[Rcpp::export]]
void connectSocket(SEXP socket_, std::string address) {
    Rcpp::XPtr<zmq::socket_t> socket(socket_);
    socket->connect(address);
}

// [[Rcpp::export]]
void disconnectSocket(SEXP socket_, std::string address) {
    Rcpp::XPtr<zmq::socket_t> socket(socket_);
    socket->disconnect(address);
}

// [[Rcpp::export]]
SEXP pollSocket(SEXP sockets_, int timeout=-1) {
    auto sockets = Rcpp::as<Rcpp::List>(sockets_);
    auto nsock = sockets.length();

    auto pitems = std::vector<zmq::pollitem_t>(nsock);
    for (int i = 0; i < nsock; i++) {
        pitems[i].socket = *Rcpp::as<Rcpp::XPtr<zmq::socket_t>>(sockets[i]);
        pitems[i].events = ZMQ_POLLIN | ZMQ_POLLOUT;
    }

    int rc = -1;
    auto start = Time::now();
    do {
        try {
            rc = zmq::poll(pitems, timeout);
        } catch(zmq::error_t& e) {
            if (errno != EINTR || pending_interrupt())
                throw e;
            if (timeout != -1) {
                ms dt = std::chrono::duration_cast<ms>(Time::now() - start);
                timeout = timeout - dt.count();
                if (timeout <= 0)
                    break;
            }
        }
    } while(rc < 0);

    auto result = Rcpp::LogicalVector(nsock);
    for (int i = 0; i < nsock; i++)
        result[i] = pitems[i].events != 0;
    return result;
}

// [[Rcpp::export]]
SEXP receiveSocket(SEXP socket_, bool dont_wait=false, bool unserialize=true) {
    Rcpp::XPtr<zmq::socket_t> socket(socket_);
    auto flags = zmq::recv_flags::none;
    if (dont_wait)
        flags = flags | zmq::recv_flags::dontwait;
    zmq::message_t message;

    if (! socket->recv(message, flags))
        return {}; // EAGAIN: no message in non-blocking mode -> empty result

    SEXP ans = Rf_allocVector(RAWSXP, message.size());
    memcpy(RAW(ans), message.data(), message.size());
    if (unserialize)
        return R_unserialize(ans);
    else
        return ans;
}

// [[Rcpp::export]]
void sendSocket(SEXP socket_, SEXP data_, bool dont_wait=false, bool send_more=false) {
    Rcpp::XPtr<zmq::socket_t> socket(socket_);
    auto flags = zmq::send_flags::none;
    if (dont_wait)
        flags = flags | zmq::send_flags::dontwait;
    if (send_more)
        flags = flags | zmq::send_flags::sndmore;

    if (TYPEOF(data_) == EXTPTRSXP) {
        Rcpp::XPtr<zmq::message_t> message(data_);
        socket->send(*message, flags);
    } else {
        if (TYPEOF(data_) != RAWSXP) {
            data_ = R_serialize(data_, R_NilValue);
        }

        zmq::message_t message(Rf_xlength(data_));
        memcpy(message.data(), RAW(data_), Rf_xlength(data_));
        socket->send(message, flags);
    }
}
