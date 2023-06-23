#include "core/or/or.h"
#include "test/test.h"
#include "test/log_test_helpers.h"
#include "lib/testsupport/testsupport.h"

#define TOR_CONGESTION_CONTROL_COMMON_PRIVATE
#define TOR_CONGESTION_CONTROL_PRIVATE
#include "core/or/congestion_control_st.h"
#include "core/or/congestion_control_common.h"

void test_congestion_control_rtt(void *arg);
void test_congestion_control_clock(void *arg);

/* =============== Clock Heuristic Test Vectors =============== */

typedef struct clock_vec
{
  uint64_t old_delta_in;
  uint64_t new_delta_in;
  bool in_slow_start_in;
  bool cached_result_out;
  bool result_out;
} clock_vec_t;

static void
run_clock_test_vec(congestion_control_t *cc,
             clock_vec_t *vec, size_t vec_len)
{
  for (size_t i = 0; i < vec_len; i++) {
    cc->in_slow_start = vec[i].in_slow_start_in;
    cc->ewma_rtt_usec = vec[i].old_delta_in*1000;
    bool ret = time_delta_stalled_or_jumped(cc,
                                            vec[i].old_delta_in,
                                            vec[i].new_delta_in);

    tt_int_op(ret, OP_EQ, vec[i].result_out);
    tt_int_op(is_monotime_clock_broken, OP_EQ, vec[i].cached_result_out);
  }

 done:
  is_monotime_clock_broken = false;
}

/**
 * This test verifies the behavior of Section 2.1.1 of
 * Prop#324 (CLOCK_HEURISTICS).
 *
 * It checks that we declare the clock value stalled,
 * and cache that value, on various time deltas.
 *
 * It also verifies that our heuristics behave correctly
 * with respect to slow start and large clock jumps/stalls.
 */
void
test_congestion_control_clock(void *arg)
{
  (void)arg;
  clock_vec_t vect1[] =
    {
      {0, 1, 1, 0, 0}, // old delta 0, slow start -> false
      {0, 0, 1, 1, 1}, // New delta 0 -> cache true, return true
      {1, 1, 1, 1, 0}, // In slow start -> keep cache, but return false
      {1, 4999, 0, 0, 0}, // Not slow start, edge -> update cache, and false
      {4999, 1, 0, 0, 0}, // Not slow start, other edge -> false
      {5001, 1, 0, 0, 0}, // Not slow start w/ -5000x -> use cache (false)
      {5001, 0, 0, 1, 1}, // New delta 0 -> cache true, return true
      {5001, 1, 0, 1, 1}, // Not slow start w/ -5000x -> use cache (true)
      {5001, 1, 1, 1, 0}, // In slow start w/ -5000x -> false
      {0, 5001, 0, 1, 0}, // Not slow start w/ no EWMA -> false
      {1, 5001, 1, 1, 0}, // In slow start w/ +5000x -> false
      {1, 1, 0, 0, 0}, // Not slow start -> update cache to false
      {5001, 1, 0, 0, 0}, // Not slow start w/ -5000x -> use cache (false)
      {1, 5001, 0, 0, 1}, // Not slow start w/ +5000x -> true
      {0, 5001, 0, 0, 0}, // Not slow start w/ no EWMA -> false
      {5001, 1, 1, 0, 0}, // In slow start w/ -5000x change -> false
      {1, 1, 0, 0, 0} // Not slow start -> false
    };

  circuit_params_t params;

  params.cc_enabled = 1;
  params.sendme_inc_cells = TLS_RECORD_MAX_CELLS;
  cc_alg = CC_ALG_VEGAS;
  congestion_control_t *cc = congestion_control_new(&params, CC_PATH_EXIT);

  run_clock_test_vec(cc, vect1, sizeof(vect1)/sizeof(clock_vec_t));

  congestion_control_free(cc);
}

/* =========== RTT Test Vectors ================== */

typedef struct rtt_vec {
  uint64_t sent_usec_in;
  uint64_t got_sendme_usec_in;
  uint64_t cwnd_in;
  bool ss_in;
  uint64_t curr_rtt_usec_out;
  uint64_t ewma_rtt_usec_out;
  uint64_t min_rtt_usec_out;
} rtt_vec_t;

static void
run_rtt_test_vec(congestion_control_t *cc,
                 rtt_vec_t *vec, size_t vec_len)
{
  for (size_t i = 0; i < vec_len; i++) {
    enqueue_timestamp(cc->sendme_pending_timestamps,
                      vec[i].sent_usec_in);
  }

  for (size_t i = 0; i < vec_len; i++) {
    cc->cwnd = vec[i].cwnd_in;
    cc->in_slow_start = vec[i].ss_in;
    uint64_t curr_rtt_usec = congestion_control_update_circuit_rtt(cc,
                                         vec[i].got_sendme_usec_in);

    tt_int_op(curr_rtt_usec, OP_EQ, vec[i].curr_rtt_usec_out);
    tt_int_op(cc->min_rtt_usec, OP_EQ, vec[i].min_rtt_usec_out);
    tt_int_op(cc->ewma_rtt_usec, OP_EQ, vec[i].ewma_rtt_usec_out);
  }
 done:
  is_monotime_clock_broken = false;
}

/**
 * This test validates current, EWMA, and minRTT calculation
 * from Sections 2.1 of Prop#324.
 *
 * We also do NOT exercise the sendme pacing code here. See
 * test_sendme_is_next() for that, in test_sendme.c.
 */
void
test_congestion_control_rtt(void *arg)
{
  (void)arg;
  rtt_vec_t vect1[] = {
    {100000, 200000, 124, 1, 100000, 100000, 100000},
    {200000, 300000, 124, 1, 100000, 100000, 100000},
    {350000, 500000, 124, 1, 150000, 133333, 100000},
    {500000, 550000, 124, 1, 50000,  77777, 77777},
    {600000, 700000, 124, 1, 100000, 92592, 77777},
    {700000, 750000, 124, 1, 50000, 64197, 64197},
    {750000, 875000, 124, 0, 125000, 104732, 104732},
    {875000, 900000, 124, 0, 25000, 51577, 104732},
    {900000, 950000, 200, 0, 50000, 50525, 50525}
  };

  circuit_params_t params;
  congestion_control_t *cc = NULL;

  params.cc_enabled = 1;
  params.sendme_inc_cells = TLS_RECORD_MAX_CELLS;
  cc_alg = CC_ALG_VEGAS;

  cc = congestion_control_new(&params, CC_PATH_EXIT);
  run_rtt_test_vec(cc, vect1, sizeof(vect1)/sizeof(rtt_vec_t));
  congestion_control_free(cc);

  return;
}

#define TEST_CONGESTION_CONTROL(name, flags) \
    { #name, test_##name, (flags), NULL, NULL }

struct testcase_t congestion_control_tests[] = {
  TEST_CONGESTION_CONTROL(congestion_control_clock, TT_FORK),
  TEST_CONGESTION_CONTROL(congestion_control_rtt, TT_FORK),
  END_OF_TESTCASES
};
