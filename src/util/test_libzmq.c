#include <zmq.h>
#if ZMQ_VERSION < ZMQ_MAKE_VERSION(4, 3, 0)
#error clustermq needs libzmq>=4.3.0
#endif
int main() {
    #ifndef ZMQ_BUILD_DRAFT_API
    return 1;
    #endif
}
