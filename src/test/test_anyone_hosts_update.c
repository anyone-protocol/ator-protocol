/* Copyright (c) 2007-2021, The Tor Project, Inc. */
/* See LICENSE for licensing information */

/**
 * \file test_anyone_hosts_update.c
 * \brief Tests for the anyone_hosts auto-update scheduling/backoff logic in
 *   feature/anyone/anyone_hosts_update.c.
 *
 * These tests mock directory_initiate_request() so that no real network
 * activity happens, and assert *when* and *which* fetches are launched:
 *   - the feature is disabled when AnyoneHostsUpdate is 0,
 *   - the periodic callback and the consensus hook are gated by the
 *     configured AnyoneHostsUpdateTrigger,
 *   - only one fetch runs at a time (overlapping fetches are prevented),
 *   - the configured update interval and the minimum retry interval are
 *     honoured, and
 *   - the round-robin URL selection advances across attempts (with the
 *     AnyoneHostsURL override taking precedence).
 **/

#define DIRCLIENT_PRIVATE

#include "core/or/or.h"
#include "feature/anyone/anyone_hosts_update.h"
#include "feature/dirclient/dirclient.h"
#include "feature/dircommon/directory.h"
#include "app/config/config.h"
#include "app/config/or_options_st.h"
#include "lib/encoding/confline.h"
#include "lib/malloc/malloc.h"

#include "test/test.h"

/* Mirror of the (file-private) timing constants in anyone_hosts_update.c so
 * the assertions below line up with the implementation. */
#define TEST_MIN_RETRY 3600
#define TEST_FETCH_TIMEOUT 600

/* Fixed wall-clock base for the tests. */
#define BASE_TIME ((time_t)1500000000)

/* ---- capture of launched directory requests ---- */

static int n_fetches_launched = 0;
static uint8_t last_dir_purpose = 0;
static char *last_onion_address = NULL;
static char *last_resource = NULL;

static void
mock_directory_initiate_request(directory_request_t *req)
{
  n_fetches_launched++;
  last_dir_purpose = req->dir_purpose;
  tor_free(last_onion_address);
  last_onion_address = req->anon_onion_address ?
    tor_strdup(req->anon_onion_address) : NULL;
  tor_free(last_resource);
  last_resource = req->resource ? tor_strdup(req->resource) : NULL;
}

static void
reset_fetch_capture(void)
{
  n_fetches_launched = 0;
  last_dir_purpose = 0;
  tor_free(last_onion_address);
  tor_free(last_resource);
}

/** Configure the update-relevant options.  With no AnyoneHostsURL override
 * the fetch source list comes from the built-in DEFAULT_ANON_DNS_MAPPING. */
static void
set_update_options(int enabled, const char *trigger, int interval)
{
  or_options_t *opt = get_options_mutable();
  opt->AnyoneHostsUpdate = enabled;
  opt->AnyoneHostsUpdateInterval = interval;
  tor_free(opt->AnyoneHostsUpdateTrigger);
  opt->AnyoneHostsUpdateTrigger = trigger ? tor_strdup(trigger) : NULL;
  tor_free(opt->AnyoneHostsFetchPath);
  opt->AnyoneHostsFetchPath = tor_strdup("/anyone_hosts");
  config_free_lines(opt->AnyoneHostsURL);
  opt->AnyoneHostsURL = NULL;
  opt->DNSMappingFileMaxSize = 0; /* no cap */
}

/* ---- tests ---- */

/** With the feature disabled, neither trigger should launch a fetch. */
static void
test_anyone_hosts_update_disabled(void *arg)
{
  (void)arg;
  MOCK(directory_initiate_request, mock_directory_initiate_request);
  reset_fetch_capture();
  anyone_hosts_update_init();

  set_update_options(0 /* disabled */, "both", 7200);

  anyone_hosts_update_callback(BASE_TIME, get_options());
  anyone_hosts_update_maybe_kick(BASE_TIME);
  tt_int_op(n_fetches_launched, OP_EQ, 0);

 done:
  UNMOCK(directory_initiate_request);
}

/** A periodic fetch is launched with the right purpose, resource, and a
 * .anyone onion target, and the callback returns the configured interval. */
static void
test_anyone_hosts_update_periodic_launch(void *arg)
{
  (void)arg;
  MOCK(directory_initiate_request, mock_directory_initiate_request);
  reset_fetch_capture();
  anyone_hosts_update_init();

  set_update_options(1, "periodic", 7200);

  int r = anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(r, OP_EQ, 7200); /* callback always reports the interval */
  tt_int_op(n_fetches_launched, OP_EQ, 1);
  tt_int_op(last_dir_purpose, OP_EQ, DIR_PURPOSE_FETCH_ANYONE_HOSTS);
  tt_assert(last_resource);
  tt_str_op(last_resource, OP_EQ, "/anyone_hosts");

  /* The target is routed by .anyone name. */
  tt_assert(last_onion_address);
  size_t l = strlen(last_onion_address);
  tt_assert(l >= 7);
  tt_str_op(last_onion_address + l - 7, OP_EQ, ".anyone");

 done:
  UNMOCK(directory_initiate_request);
}

/** The trigger setting routes which entry point may launch a fetch. */
static void
test_anyone_hosts_update_trigger_routing(void *arg)
{
  (void)arg;
  MOCK(directory_initiate_request, mock_directory_initiate_request);

  /* "periodic": only the periodic callback launches. */
  reset_fetch_capture();
  anyone_hosts_update_init();
  set_update_options(1, "periodic", 7200);
  anyone_hosts_update_maybe_kick(BASE_TIME);
  tt_int_op(n_fetches_launched, OP_EQ, 0);
  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* "consensus": only the consensus hook launches. */
  reset_fetch_capture();
  anyone_hosts_update_init();
  set_update_options(1, "consensus", 7200);
  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 0);
  anyone_hosts_update_maybe_kick(BASE_TIME);
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* "both": the periodic callback launches (fresh state). */
  reset_fetch_capture();
  anyone_hosts_update_init();
  set_update_options(1, "both", 7200);
  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* "both": the consensus hook launches (fresh state). */
  reset_fetch_capture();
  anyone_hosts_update_init();
  set_update_options(1, "both", 7200);
  anyone_hosts_update_maybe_kick(BASE_TIME);
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* An unrecognised trigger launches nothing. */
  reset_fetch_capture();
  anyone_hosts_update_init();
  set_update_options(1, "bogus", 7200);
  anyone_hosts_update_callback(BASE_TIME, get_options());
  anyone_hosts_update_maybe_kick(BASE_TIME);
  tt_int_op(n_fetches_launched, OP_EQ, 0);

 done:
  UNMOCK(directory_initiate_request);
}

/** While a fetch is in progress, further triggers must not start a second,
 * overlapping fetch. */
static void
test_anyone_hosts_update_no_overlap(void *arg)
{
  (void)arg;
  MOCK(directory_initiate_request, mock_directory_initiate_request);
  reset_fetch_capture();
  anyone_hosts_update_init();

  set_update_options(1, "both", 7200);

  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* Both entry points are no-ops while the first fetch is in flight. */
  anyone_hosts_update_callback(BASE_TIME, get_options());
  anyone_hosts_update_maybe_kick(BASE_TIME);
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* Once the fetch reports success the flag clears, but the success interval
   * now blocks an immediate refetch. */
  anyone_hosts_update_note_result(1, BASE_TIME);
  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

 done:
  UNMOCK(directory_initiate_request);
}

/** After a success, the configured interval must elapse before the next
 * fetch. */
static void
test_anyone_hosts_update_interval_after_success(void *arg)
{
  (void)arg;
  MOCK(directory_initiate_request, mock_directory_initiate_request);
  reset_fetch_capture();
  anyone_hosts_update_init();

  set_update_options(1, "periodic", 7200);

  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);
  anyone_hosts_update_note_result(1, BASE_TIME);

  /* Before the interval elapses: blocked. */
  anyone_hosts_update_callback(BASE_TIME + 7199, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* At the interval boundary: a fresh fetch launches. */
  anyone_hosts_update_callback(BASE_TIME + 7200, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 2);

 done:
  UNMOCK(directory_initiate_request);
}

/** After a failure, the minimum retry interval prevents a retry storm. */
static void
test_anyone_hosts_update_retry_backoff(void *arg)
{
  (void)arg;
  MOCK(directory_initiate_request, mock_directory_initiate_request);
  reset_fetch_capture();
  anyone_hosts_update_init();

  set_update_options(1, "periodic", 7200);

  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);
  anyone_hosts_update_note_result(0 /* failure */, BASE_TIME);

  /* Well within the minimum retry interval: no retry. */
  anyone_hosts_update_callback(BASE_TIME + 60, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);
  anyone_hosts_update_callback(BASE_TIME + (TEST_MIN_RETRY - 1), get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* Once the minimum retry interval elapses, a retry is allowed. */
  anyone_hosts_update_callback(BASE_TIME + TEST_MIN_RETRY, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 2);

 done:
  UNMOCK(directory_initiate_request);
}

/** Consecutive attempts round-robin to different servers, and an
 * AnyoneHostsURL override is tried first. */
static void
test_anyone_hosts_update_url_selection(void *arg)
{
  (void)arg;
  char *first = NULL;
  MOCK(directory_initiate_request, mock_directory_initiate_request);
  reset_fetch_capture();
  anyone_hosts_update_init();

  set_update_options(1, "periodic", 7200);

  /* First attempt. */
  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);
  tt_assert(last_onion_address);
  first = tor_strdup(last_onion_address);

  /* A failed attempt advances the round-robin index. */
  anyone_hosts_update_note_result(0, BASE_TIME);
  anyone_hosts_update_callback(BASE_TIME + TEST_MIN_RETRY, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 2);
  tt_assert(last_onion_address);
  /* The second attempt targets a different server. */
  tt_str_op(last_onion_address, OP_NE, first);

  /* With an explicit AnyoneHostsURL override, that address is tried first. */
  reset_fetch_capture();
  anyone_hosts_update_init();
  set_update_options(1, "periodic", 7200);
  config_line_append(&get_options_mutable()->AnyoneHostsURL,
                     "AnyoneHostsURL", "override1.anyone");
  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);
  tt_assert(last_onion_address);
  tt_str_op(last_onion_address, OP_EQ, "override1.anyone");

 done:
  tor_free(first);
  UNMOCK(directory_initiate_request);
}

/** A fetch that never reports a result is eventually treated as failed so it
 * does not block updates forever. */
static void
test_anyone_hosts_update_stuck_timeout(void *arg)
{
  (void)arg;
  MOCK(directory_initiate_request, mock_directory_initiate_request);
  reset_fetch_capture();
  anyone_hosts_update_init();

  set_update_options(1, "periodic", 7200);

  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* The in-progress flag blocks new fetches before the stuck timeout. */
  anyone_hosts_update_callback(BASE_TIME + 1, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* At the timeout the stuck fetch is cleared, but no new fetch is launched
   * in the same call. */
  anyone_hosts_update_callback(BASE_TIME + TEST_FETCH_TIMEOUT, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* After the minimum retry interval, a fresh fetch can proceed. */
  anyone_hosts_update_callback(BASE_TIME + TEST_MIN_RETRY, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 2);

 done:
  UNMOCK(directory_initiate_request);
}

struct testcase_t anyone_hosts_update_tests[] = {
  { "disabled", test_anyone_hosts_update_disabled, TT_FORK, NULL, NULL },
  { "periodic_launch", test_anyone_hosts_update_periodic_launch, TT_FORK,
    NULL, NULL },
  { "trigger_routing", test_anyone_hosts_update_trigger_routing, TT_FORK,
    NULL, NULL },
  { "no_overlap", test_anyone_hosts_update_no_overlap, TT_FORK, NULL, NULL },
  { "interval_after_success", test_anyone_hosts_update_interval_after_success,
    TT_FORK, NULL, NULL },
  { "retry_backoff", test_anyone_hosts_update_retry_backoff, TT_FORK,
    NULL, NULL },
  { "url_selection", test_anyone_hosts_update_url_selection, TT_FORK,
    NULL, NULL },
  { "stuck_timeout", test_anyone_hosts_update_stuck_timeout, TT_FORK,
    NULL, NULL },
  END_OF_TESTCASES
};
