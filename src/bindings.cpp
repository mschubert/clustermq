#include <Rcpp.h>
#include <chrono>
#include <string>
#include "zmq.hpp"

typedef std::chrono::high_resolution_clock Time;
typedef std::chrono::milliseconds ms;
Rcpp::Function R_serialize("serialize");
Rcpp::Function R_unserialize("unserialize");

int str2socket_(std::string str) {
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
SEXP init_context(int threads=1) {
    auto context_ = new zmq::context_t(threads);
    Rcpp::XPtr<zmq::context_t> context(context_, true);
    return context;
}

// [[Rcpp::export]]
SEXP init_socket(SEXP context, std::string socket_type) {
    Rcpp::XPtr<zmq::context_t> context_(context);
    auto socket_type_ = str2socket_(socket_type);
    auto socket_ = new zmq::socket_t(*context_, socket_type_);
    Rcpp::XPtr<zmq::socket_t> socket(socket_, true);
    return socket;
}

// [[Rcpp::export]]
void bind_socket(SEXP socket, std::string address) {
    Rcpp::XPtr<zmq::socket_t> socket_(socket);
    socket_->bind(address);
}

// [[Rcpp::export]]
void connect_socket(SEXP socket, std::string address) {
    Rcpp::XPtr<zmq::socket_t> socket_(socket);
    socket_->connect(address);
}

// [[Rcpp::export]]
void disconnect_socket(SEXP socket, std::string address) {
    Rcpp::XPtr<zmq::socket_t> socket_(socket);
    socket_->disconnect(address);
}

// [[Rcpp::export]]
SEXP poll_socket(SEXP sockets, int timeout=-1) {
    auto sockets_ = Rcpp::as<Rcpp::List>(sockets);
    auto nsock = sockets_.length();

    auto pitems = std::vector<zmq::pollitem_t>(nsock);
    for (int i = 0; i < nsock; i++) {
        pitems[i].socket = *Rcpp::as<Rcpp::XPtr<zmq::socket_t>>(sockets_[i]);
        pitems[i].events = ZMQ_POLLIN; // | ZMQ_POLLOUT; ssh_proxy XREP/XREQ has 2200
    }

    int rc = -1;
    auto start = Time::now();
    do {
        try {
            rc = zmq::poll(pitems, timeout);
        } catch(zmq::error_t &e) {
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

    auto result = Rcpp::IntegerVector(nsock);
    for (int i = 0; i < nsock; i++)
        result[i] = pitems[i].revents;
    return result;
}

zmq::message_t rcv_msg(SEXP socket, bool dont_wait=false) {
    Rcpp::XPtr<zmq::socket_t> socket_(socket);
    auto flags = zmq::recv_flags::none;
    if (dont_wait)
        flags = flags | zmq::recv_flags::dontwait;

    zmq::message_t message;
    socket_->recv(message, flags);
    return message;
}

// [[Rcpp::export]]
SEXP receive_socket(SEXP socket, bool dont_wait=false, bool unserialize=true) {
    auto message = rcv_msg(socket, dont_wait);
//    if (! socket_->recv(message, flags))
//        return {}; // EAGAIN: no message in non-blocking mode -> empty result

    SEXP ans = Rf_allocVector(RAWSXP, message.size());
    memcpy(RAW(ans), message.data(), message.size());
    if (unserialize)
        return R_unserialize(ans);
    else
        return ans;
}

// [[Rcpp::export]]
Rcpp::List receive_multipart(SEXP socket, bool dont_wait=false, bool unserialize=true) {
    zmq::message_t message;
    Rcpp::List result;
    do {
        message = rcv_msg(socket, dont_wait);
        SEXP ans = Rf_allocVector(RAWSXP, message.size());
        memcpy(RAW(ans), message.data(), message.size());

        if (unserialize)
            result.push_back(R_unserialize(ans));
        else
            result.push_back(ans);
    } while (message.more());

    return result;
}

// [[Rcpp::export]]
void send_socket(SEXP socket, SEXP data, bool dont_wait=false, bool send_more=false) {
    Rcpp::XPtr<zmq::socket_t> socket_(socket);
    auto flags = zmq::send_flags::none;
    if (dont_wait)
        flags = flags | zmq::send_flags::dontwait;
    if (send_more)
        flags = flags | zmq::send_flags::sndmore;

    if (TYPEOF(data) != RAWSXP)
        data = R_serialize(data, R_NilValue);

    zmq::message_t message(Rf_xlength(data));
    memcpy(message.data(), RAW(data), Rf_xlength(data));
    socket_->send(message, flags);
}
