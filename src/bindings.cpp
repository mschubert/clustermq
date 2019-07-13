#include <Rcpp.h>
#include <zmq.hpp>
#include <chrono>
#include <string>

typedef std::chrono::high_resolution_clock Time;
typedef std::chrono::milliseconds ms;

/* Check for interrupt without long jumping */
void check_interrupt_fn(void *dummy) {
    R_CheckUserInterrupt();
}

int pending_interrupt() {
    return !(R_ToplevelExec(check_interrupt_fn, NULL));
}

// [[Rcpp::export]]
SEXP initContext(SEXP threads_) {
    auto context = new zmq::context_t(Rcpp::as<int>(threads_));
    Rcpp::XPtr<zmq::context_t> context_(context, true);
    return context_;
}

// [[Rcpp::export]]
SEXP initSocket(SEXP context_, SEXP socket_type_) { // socket_type_ is INT
    Rcpp::XPtr<zmq::context_t> context(context_);
    auto socket_type = Rcpp::as<int>(socket_type_);
    auto socket = new zmq::socket_t(*context, socket_type);
    Rcpp::XPtr<zmq::socket_t> socket_(socket, true); // check: does this catch failed allocation?
    return socket_;
}

// [[Rcpp::export]]
SEXP initMessage(SEXP data_) {
    if (TYPEOF(data_) != RAWSXP) // could serialize + nocopy here
        Rf_error("initMessage expects type RAWSXP");
    auto message = new zmq::message_t(Rf_xlength(data_));
    memcpy(message->data(), RAW(data_), Rf_xlength(data_));
    // no copy below, see first that one copy works
    // zmq::message_t msg(reinterpret_cast<void*>(data_), Rf_xlength(data_), NULL);
    Rcpp::XPtr<zmq::message_t> message_(message, true);
    return message_;
}

// [[Rcpp::export]]
void bindSocket(SEXP socket_, SEXP address_) {
    Rcpp::XPtr<zmq::socket_t> socket(socket_);
    socket->bind(Rcpp::as<std::string>(address_));
}

// [[Rcpp::export]]
void connectSocket(SEXP socket_, SEXP address_) {
    Rcpp::XPtr<zmq::socket_t> socket(socket_);
    socket->connect(Rcpp::as<std::string>(address_));
}

// [[Rcpp::export]]
void disconnectSocket(SEXP socket_, SEXP address_) {
    Rcpp::XPtr<zmq::socket_t> socket(socket_);
    socket->disconnect(Rcpp::as<std::string>(address_));
}

// [[Rcpp::export]]
SEXP pollSocket(SEXP sockets_, SEXP events_, SEXP timeout_) { // events is INT!! (ZMQ_POLLIN|OUT|ERR)
    auto sockets = Rcpp::as<Rcpp::List>(sockets_);
    auto events = Rcpp::as<Rcpp::IntegerVector>(events_);
    auto timeout = Rcpp::as<int>(timeout_);
    auto nsock = sockets.length();

    if (sockets.length() == 0 | sockets.length() != events.length())
        Rf_error("socket length must be equal events and >= 1");

    auto pitems = std::vector<zmq::pollitem_t>(nsock);
    for (int i = 0; i < nsock; i++) {
        auto socket = Rcpp::as<Rcpp::XPtr<zmq::socket_t>>(sockets[i]);
        pitems[i].socket = static_cast<void*>(socket);
        pitems[i].events = events[i];
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

    auto result = Rcpp::IntegerVector(nsock);
    for (int i = 0; i < nsock; i++)
        result[i] = pitems[i].events;
    return result;
}

// [[Rcpp::export]]
SEXP receiveSocket(SEXP socket_, SEXP dont_wait_) {
    Rcpp::XPtr<zmq::socket_t> socket(socket_); // does this check valid pointer?
    auto dont_wait = Rcpp::as<bool>(dont_wait_);
    zmq::message_t message;
    auto success = socket->recv(&message, dont_wait); // does this throw on error already?

    SEXP ans = Rf_allocVector(RAWSXP, message.size());
    memcpy(RAW(ans), message.data(), message.size());
    return ans;
}

// [[Rcpp::export]]
void sendSocket(SEXP socket_, SEXP data_, SEXP send_more_) {
    Rcpp::XPtr<zmq::socket_t> socket(socket_); // does this check valid pointer?
    if (TYPEOF(data_) != RAWSXP)
        Rf_error("data type must be raw (RAWSXP).\n");

    zmq::message_t message(Rf_xlength(data_));
    memcpy(message.data(), RAW(data_), Rf_xlength(data_));

    auto send_more = Rcpp::as<bool>(send_more_);
    if (send_more)
        socket->send(message, ZMQ_SNDMORE);
    else
        socket->send(message);
}

// [[Rcpp::export]]
void sendMessageObject(SEXP socket_, SEXP message_, SEXP send_more_) {
    Rcpp::XPtr<zmq::socket_t> socket(socket_); // does this check valid pointer?
    Rcpp::XPtr<zmq::message_t> message(message_); // does this check valid pointer?

    auto send_more = Rcpp::as<bool>(send_more_);
    if (send_more)
        socket->send(*message, ZMQ_SNDMORE);
    else
        socket->send(*message);
}
