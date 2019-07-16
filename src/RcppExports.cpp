// Generated by using Rcpp::compileAttributes() -> do not edit by hand
// Generator token: 10BE3573-1514-4C36-9D1C-5A225CD40393

#include <Rcpp.h>

using namespace Rcpp;

// initContext
SEXP initContext(SEXP threads_);
RcppExport SEXP _clustermq_initContext(SEXP threads_SEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type threads_(threads_SEXP);
    rcpp_result_gen = Rcpp::wrap(initContext(threads_));
    return rcpp_result_gen;
END_RCPP
}
// initSocket
SEXP initSocket(SEXP context_, SEXP socket_type_);
RcppExport SEXP _clustermq_initSocket(SEXP context_SEXP, SEXP socket_type_SEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type context_(context_SEXP);
    Rcpp::traits::input_parameter< SEXP >::type socket_type_(socket_type_SEXP);
    rcpp_result_gen = Rcpp::wrap(initSocket(context_, socket_type_));
    return rcpp_result_gen;
END_RCPP
}
// initMessage
SEXP initMessage(SEXP data_);
RcppExport SEXP _clustermq_initMessage(SEXP data_SEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type data_(data_SEXP);
    rcpp_result_gen = Rcpp::wrap(initMessage(data_));
    return rcpp_result_gen;
END_RCPP
}
// bindSocket
void bindSocket(SEXP socket_, SEXP address_);
RcppExport SEXP _clustermq_bindSocket(SEXP socket_SEXP, SEXP address_SEXP) {
BEGIN_RCPP
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type socket_(socket_SEXP);
    Rcpp::traits::input_parameter< SEXP >::type address_(address_SEXP);
    bindSocket(socket_, address_);
    return R_NilValue;
END_RCPP
}
// connectSocket
void connectSocket(SEXP socket_, SEXP address_);
RcppExport SEXP _clustermq_connectSocket(SEXP socket_SEXP, SEXP address_SEXP) {
BEGIN_RCPP
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type socket_(socket_SEXP);
    Rcpp::traits::input_parameter< SEXP >::type address_(address_SEXP);
    connectSocket(socket_, address_);
    return R_NilValue;
END_RCPP
}
// disconnectSocket
void disconnectSocket(SEXP socket_, SEXP address_);
RcppExport SEXP _clustermq_disconnectSocket(SEXP socket_SEXP, SEXP address_SEXP) {
BEGIN_RCPP
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type socket_(socket_SEXP);
    Rcpp::traits::input_parameter< SEXP >::type address_(address_SEXP);
    disconnectSocket(socket_, address_);
    return R_NilValue;
END_RCPP
}
// pollSocket
SEXP pollSocket(SEXP sockets_, SEXP timeout_);
RcppExport SEXP _clustermq_pollSocket(SEXP sockets_SEXP, SEXP timeout_SEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type sockets_(sockets_SEXP);
    Rcpp::traits::input_parameter< SEXP >::type timeout_(timeout_SEXP);
    rcpp_result_gen = Rcpp::wrap(pollSocket(sockets_, timeout_));
    return rcpp_result_gen;
END_RCPP
}
// receiveSocket
SEXP receiveSocket(SEXP socket_, SEXP dont_wait_);
RcppExport SEXP _clustermq_receiveSocket(SEXP socket_SEXP, SEXP dont_wait_SEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type socket_(socket_SEXP);
    Rcpp::traits::input_parameter< SEXP >::type dont_wait_(dont_wait_SEXP);
    rcpp_result_gen = Rcpp::wrap(receiveSocket(socket_, dont_wait_));
    return rcpp_result_gen;
END_RCPP
}
// sendSocket
void sendSocket(SEXP socket_, SEXP data_, SEXP send_more_);
RcppExport SEXP _clustermq_sendSocket(SEXP socket_SEXP, SEXP data_SEXP, SEXP send_more_SEXP) {
BEGIN_RCPP
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type socket_(socket_SEXP);
    Rcpp::traits::input_parameter< SEXP >::type data_(data_SEXP);
    Rcpp::traits::input_parameter< SEXP >::type send_more_(send_more_SEXP);
    sendSocket(socket_, data_, send_more_);
    return R_NilValue;
END_RCPP
}
// sendMessageObject
void sendMessageObject(SEXP socket_, SEXP message_, SEXP send_more_);
RcppExport SEXP _clustermq_sendMessageObject(SEXP socket_SEXP, SEXP message_SEXP, SEXP send_more_SEXP) {
BEGIN_RCPP
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type socket_(socket_SEXP);
    Rcpp::traits::input_parameter< SEXP >::type message_(message_SEXP);
    Rcpp::traits::input_parameter< SEXP >::type send_more_(send_more_SEXP);
    sendMessageObject(socket_, message_, send_more_);
    return R_NilValue;
END_RCPP
}

static const R_CallMethodDef CallEntries[] = {
    {"_clustermq_initContext", (DL_FUNC) &_clustermq_initContext, 1},
    {"_clustermq_initSocket", (DL_FUNC) &_clustermq_initSocket, 2},
    {"_clustermq_initMessage", (DL_FUNC) &_clustermq_initMessage, 1},
    {"_clustermq_bindSocket", (DL_FUNC) &_clustermq_bindSocket, 2},
    {"_clustermq_connectSocket", (DL_FUNC) &_clustermq_connectSocket, 2},
    {"_clustermq_disconnectSocket", (DL_FUNC) &_clustermq_disconnectSocket, 2},
    {"_clustermq_pollSocket", (DL_FUNC) &_clustermq_pollSocket, 2},
    {"_clustermq_receiveSocket", (DL_FUNC) &_clustermq_receiveSocket, 2},
    {"_clustermq_sendSocket", (DL_FUNC) &_clustermq_sendSocket, 3},
    {"_clustermq_sendMessageObject", (DL_FUNC) &_clustermq_sendMessageObject, 3},
    {NULL, NULL, 0}
};

RcppExport void R_init_clustermq(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
