#include <zmq.h>
int main() {
    #if defined(ZMQ_BUILD_DRAFT_API) && ZMQ_VERSION >= ZMQ_MAKE_VERSION(4, 3, 0)
    return 0;
    #endif
    return 1;
}
