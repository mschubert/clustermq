# NA

codex resume 019d633d-5c80-7930-9f22-4200adf997ab

You are correct: the change I made frees a slot when the worker’s result
comes back, so it gates transfer plus computation. I’ll revert that
incorrect approach and replace it with a transfer-completion design, or
leave a concrete protocol sketch if the code change would require a
broader protocol refactor.

• Edited src/CMQMaster.h (+0 -36) 1 \#include \<Rcpp.h\> 2 -#include 2
\#include “common.h” ⋮ 78 env.clear(); 80 -
std::queue().swap(recv_buffer); 79 pending_workers = 0; ⋮ 92 SEXP
recv(int timeout=-1) { 95 - if (!recv_buffer.empty()) { 96 - auto
buffered = std::move(recv_buffer.front()); 97 - recv_buffer.pop(); 98 -
cur = buffered.peer; 99 - return msg2r(std::move(buffered.data), true);
100 - } 101 - 93 int data_offset; ⋮ 114 int send_eval(SEXP cmd) { 124 -
auto target = cur; 125 - wait_for_send_slot(); 126 - cur = target; 115
auto &w = check_current_worker(wlife_t::active); ⋮ 240 private: 253 -
static const int max_parallel_sends = 3; 254 - 255 - struct
recv_buffer_t { 256 - std::string peer; 257 - zmq::message_t data; 258 -
}; 259 - 241 struct worker_t { ⋮ 258 std::unordered_map\<std::string,
worker_t\> peers; 278 - std::queue recv_buffer; 259
std::unordered_map\<std::string, zmq::message_t\> env; ⋮ 284
mp.push_back(zmq::message_t(obj.data(), obj.size(),
[](void*,%20void*))); 305 - } 306 - 307 - int sends_in_flight() const {
308 - return std::count_if(peers.begin(), peers.end(),
[](const%20std::pair%3Cstd::string,%20worker_t%3E%20&w) { 309 - return
w.second.call != R_NilValue; }); 310 - } 311 - 312 - void
wait_for_send_slot() { 313 - while (sends_in_flight() \>=
max_parallel_sends) { 314 - poll(-1); 315 - std::vector msgs; 316 - auto
n = recv_multipart(sock, std::back_inserter(msgs)); 317 - int
data_offset = register_peer(msgs); 318 - if (data_offset \< msgs.size())
319 - recv_buffer.push(recv_buffer_t{cur,
std::move(msgs\[data_offset\])}); 320 - } 285 }

──────────────────────────────────────────────────────────────────────────────────────────────────────────────────

• I reverted the incorrect in-flight-result cap. I’m checking the tree
now so we don’t leave that mistaken implementation in the repository.

• Ran git diff – src/CMQMaster.h └ (no output)

• Ran git status –short └ m src/libzmq

──────────────────────────────────────────────────────────────────────────────────────────────────────────────────

• Yes. Your understanding is correct, and that means the change was
wrong for your goal.

I reverted it, so src/CMQMaster.h is back to no diff.

The issue is that w.call != R_NilValue tracks “worker has an outstanding
eval request”. That slot is cleared in register_peer() only when the
worker sends its final response, which happens after:

1.  Master-to-worker data transfer.
2.  Worker unserialization/setup.
3.  Worker computation.
4.  Worker-to-master result transfer.

For “limit only large outbound transfers”, you need a separate
transfer-complete signal, not the existing result response.

With ZeroMQ, send() returning is also not enough: it means the multipart
message was accepted into ZeroMQ’s queues, not that the peer has
finished receiving it over the network.

The robust fix is a protocol change:

- Add a transfer ACK sent by the worker immediately after it has
  received the full eval multipart and updated its environment, but
  before evaluating the command.
- The master maintains transfers_in_flight, capped at 3.
- send_eval() waits only for transfer ACKs when the cap is full.
- Final eval results remain separately tracked with the existing w.call
  / call_ref.

Because workers currently use ZMQ_REQ, they cannot send both an ACK and
a later result without another request from the master. So either:

- Switch worker sockets from REQ to DEALER, keeping master as ROUTER,
  which allows worker to send transfer_ack and later result.
- Or keep REQ and make eval two-phase: master sends large “stage eval”
  payload, worker sends ACK, master sends tiny “execute” request, worker
  computes and sends result.

I’d favor the ROUTER/DEALER approach if you’re willing to touch the
protocol, because the ACK/result split maps directly to what you need.
