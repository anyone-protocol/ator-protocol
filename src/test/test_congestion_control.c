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

#define TEST_CONGESTION_CONTROL(name, flags) \
    { #name, test_##name, (flags), NULL, NULL }

struct testcase_t congestion_control_tests[] = {
  TEST_CONGESTION_CONTROL(congestion_control_clock, TT_FORK),
  END_OF_TESTCASES
};
