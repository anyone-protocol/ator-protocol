/* Copyright (c) 2007-2021, The Tor Project, Inc. */
/* See LICENSE for licensing information */

/**
 * \file test_anyone_hosts_update.c
 * \brief Tests for the anyone_hosts auto-update logic in
 *   feature/anyone/anyone_hosts_update.c.
 *
 * The scheduling tests mock directory_initiate_request() so that no real
 * network activity happens, and assert *when* and *which* fetches are
 * launched.  The response tests mock anyone_hosts_parse_and_verify_ex()
 * (driven by markers embedded in the test bodies) and assert which fetched
 * documents are installed.
 **/

#define DIRCLIENT_PRIVATE
#define ANYONE_HOSTS_UPDATE_PRIVATE

#include "core/or/or.h"
#include "feature/anyone/anyone_hosts_update.h"
#include "feature/dirclient/dirclient.h"
#include "feature/dircommon/directory.h"
#include "feature/dirparse/anyone_hosts_parse.h"
#include "app/config/config.h"
#include "app/config/or_options_st.h"
#include "lib/encoding/confline.h"
#include "lib/fs/files.h"
#include "lib/fs/dir.h"
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
 * the fetch target list comes from the built-in DEFAULT_ANON_DNS_MAPPING. */
static void
set_update_options(int enabled, int interval)
{
  or_options_t *opt = get_options_mutable();
  opt->AnyoneHostsUpdate = enabled;
  opt->AnyoneHostsUpdateInterval = interval;
  config_free_lines(opt->AnyoneHostsURL);
  opt->AnyoneHostsURL = NULL;
  opt->DNSMappingFileMaxSize = 0; /* no cap */
}

/** Assert that a jittered periodic-callback return value <b>r</b> is within
 * +/-10% of <b>interval</b>. */
#define ASSERT_JITTERED_INTERVAL(r, interval)              \
  do {                                                     \
    tt_int_op((r), OP_GE, (interval) - (interval) / 10);   \
    tt_int_op((r), OP_LE, (interval) + (interval) / 10);   \
  } while (0)

/* ---- mock signature verification for the response tests ----
 *
 * The mock derives its result from markers in the body:
 *   "SIG=VALID" / "SIG=UNSIGNED" / "SIG=INVALID"  -> returned status
 *   "PUB=<n>"                                     -> *published_out = n
 *   "VU=<n>"                                      -> *valid_until_out = n
 */
static anyone_hosts_sig_status_t
mock_parse_and_verify_ex(const char *body, size_t body_len,
                         time_t *published_out, time_t *valid_until_out)
{
  (void)body_len;
  const char *m;
  if (published_out) {
    *published_out = 0;
    if ((m = strstr(body, "PUB=")))
      *published_out = (time_t)atoi(m + 4);
  }
  if (valid_until_out) {
    *valid_until_out = 0;
    if ((m = strstr(body, "VU=")))
      *valid_until_out = (time_t)atoi(m + 3);
  }
  if (strstr(body, "SIG=VALID"))
    return ANYONE_HOSTS_SIG_VALID;
  if (strstr(body, "SIG=INVALID"))
    return ANYONE_HOSTS_SIG_INVALID;
  return ANYONE_HOSTS_SIG_UNSIGNED;
}

/* ---- scheduling tests ---- */

/** With the feature disabled, neither trigger should launch a fetch. */
static void
test_anyone_hosts_update_disabled(void *arg)
{
  (void)arg;
  MOCK(directory_initiate_request, mock_directory_initiate_request);
  reset_fetch_capture();
  anyone_hosts_update_init();

  set_update_options(0 /* disabled */, 7200);

  anyone_hosts_update_callback(BASE_TIME, get_options());
  anyone_hosts_update_maybe_kick(BASE_TIME);
  tt_int_op(n_fetches_launched, OP_EQ, 0);

 done:
  UNMOCK(directory_initiate_request);
}

/** Servers (even ones with the CLIENT role) must not auto-update. */
static void
test_anyone_hosts_update_server_mode(void *arg)
{
  (void)arg;
  MOCK(directory_initiate_request, mock_directory_initiate_request);
  reset_fetch_capture();
  anyone_hosts_update_init();

  set_update_options(1, 7200);
  get_options_mutable()->ORPort_set = 1;

  anyone_hosts_update_callback(BASE_TIME, get_options());
  anyone_hosts_update_maybe_kick(BASE_TIME);
  tt_int_op(n_fetches_launched, OP_EQ, 0);

 done:
  get_options_mutable()->ORPort_set = 0;
  UNMOCK(directory_initiate_request);
}

/** A periodic fetch is launched with the right purpose, resource, and a
 * .anyone onion target, and the callback returns a jittered interval. */
static void
test_anyone_hosts_update_periodic_launch(void *arg)
{
  (void)arg;
  MOCK(directory_initiate_request, mock_directory_initiate_request);
  reset_fetch_capture();
  anyone_hosts_update_init();

  set_update_options(1, 7200);

  int r = anyone_hosts_update_callback(BASE_TIME, get_options());
  ASSERT_JITTERED_INTERVAL(r, 7200);
  tt_int_op(n_fetches_launched, OP_EQ, 1);
  tt_int_op(last_dir_purpose, OP_EQ, DIR_PURPOSE_FETCH_ANYONE_HOSTS);
  tt_assert(last_resource);
  tt_str_op(last_resource, OP_EQ, ANYONE_HOSTS_FETCH_PATH);

  /* The target is routed by .anyone name. */
  tt_assert(last_onion_address);
  size_t l = strlen(last_onion_address);
  tt_assert(l >= 7);
  tt_str_op(last_onion_address + l - 7, OP_EQ, ".anyone");

 done:
  UNMOCK(directory_initiate_request);
}

/** The consensus hook may launch a fetch too. */
static void
test_anyone_hosts_update_consensus_kick(void *arg)
{
  (void)arg;
  MOCK(directory_initiate_request, mock_directory_initiate_request);
  reset_fetch_capture();
  anyone_hosts_update_init();

  set_update_options(1, 7200);

  anyone_hosts_update_maybe_kick(BASE_TIME);
  tt_int_op(n_fetches_launched, OP_EQ, 1);
  tt_int_op(last_dir_purpose, OP_EQ, DIR_PURPOSE_FETCH_ANYONE_HOSTS);

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

  set_update_options(1, 7200);

  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* Both entry points are no-ops while the first fetch is in flight. */
  anyone_hosts_update_callback(BASE_TIME, get_options());
  anyone_hosts_update_maybe_kick(BASE_TIME);
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* Once the fetch reports success the flag clears, but the success
   * interval now blocks an immediate refetch. */
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

  set_update_options(1, 7200);

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

  set_update_options(1, 7200);

  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);
  anyone_hosts_update_note_result(0 /* failure */, BASE_TIME);

  /* Well within the minimum retry interval: no retry. */
  anyone_hosts_update_callback(BASE_TIME + 60, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);
  anyone_hosts_update_callback(BASE_TIME + (TEST_MIN_RETRY - 1),
                               get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* Once the minimum retry interval elapses, a retry is allowed. */
  anyone_hosts_update_callback(BASE_TIME + TEST_MIN_RETRY, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 2);

 done:
  UNMOCK(directory_initiate_request);
}

/** An AnyoneHostsURL override is tried first; a failure advances to the
 * next target, and a success keeps the working target. */
static void
test_anyone_hosts_update_url_selection(void *arg)
{
  (void)arg;
  MOCK(directory_initiate_request, mock_directory_initiate_request);
  reset_fetch_capture();
  anyone_hosts_update_init();

  set_update_options(1, 7200);
  config_line_append(&get_options_mutable()->AnyoneHostsURL,
                     "AnyoneHostsURL", "override1.anyone");

  /* The override is tried first. */
  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);
  tt_assert(last_onion_address);
  tt_str_op(last_onion_address, OP_EQ, "override1.anyone");

  /* A success does NOT advance the target: the next fetch (after the
   * interval) goes to the same working server. */
  anyone_hosts_update_note_result(1, BASE_TIME);
  anyone_hosts_update_callback(BASE_TIME + 7200, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 2);
  tt_str_op(last_onion_address, OP_EQ, "override1.anyone");

  /* A failure advances to the next target in the list. */
  anyone_hosts_update_note_result(0, BASE_TIME + 7200);
  anyone_hosts_update_callback(BASE_TIME + 7200 + TEST_MIN_RETRY,
                               get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 3);
  tt_assert(last_onion_address);
  tt_str_op(last_onion_address, OP_NE, "override1.anyone");

 done:
  UNMOCK(directory_initiate_request);
}

/** A fetch that never reports a result is eventually treated as failed so
 * it does not block updates forever. */
static void
test_anyone_hosts_update_stuck_timeout(void *arg)
{
  (void)arg;
  MOCK(directory_initiate_request, mock_directory_initiate_request);
  reset_fetch_capture();
  anyone_hosts_update_init();

  set_update_options(1, 7200);

  anyone_hosts_update_callback(BASE_TIME, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* The in-progress flag blocks new fetches before the stuck timeout. */
  anyone_hosts_update_callback(BASE_TIME + 1, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* At the timeout the stuck fetch is cleared, but no new fetch is
   * launched in the same call. */
  anyone_hosts_update_callback(BASE_TIME + TEST_FETCH_TIMEOUT,
                               get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 1);

  /* After the minimum retry interval, a fresh fetch can proceed. */
  anyone_hosts_update_callback(BASE_TIME + TEST_MIN_RETRY, get_options());
  tt_int_op(n_fetches_launched, OP_EQ, 2);

 done:
  UNMOCK(directory_initiate_request);
}

/* ---- helper tests ---- */

/** anyone_hosts_extract_addresses() finds mapping targets, tolerates tab
 * separators, and skips the signed-format metadata lines. */
static void
test_anyone_hosts_update_extract_addresses(void *arg)
{
  (void)arg;
  smartlist_t *out = smartlist_new();

  static const char doc[] =
    "anyone-hosts-version 1\n"
    "anyone-hosts-status signed\n"
    "published 2026-01-01 00:00:00\n"
    "valid-until 2026-02-01 00:00:00\n"
    "one.anyone.anyone aaaa.anyone\n"
    "two.anyone.anyone\tbbbb.anyone\n"
    "bad-line-no-address\n"
    "bad.anyone.anyone not-an-anyone-address\n"
    "anyone-hosts-digest sha256 abc\n"
    "anyone-hosts-signature cccc.anyone\n"
    "-----BEGIN SIGNATURE-----\n"
    "AAAA\n"
    "-----END SIGNATURE-----\n";

  int n = anyone_hosts_extract_addresses(doc, out);
  tt_int_op(n, OP_EQ, 2);
  tt_int_op(smartlist_len(out), OP_EQ, 2);
  tt_str_op(smartlist_get(out, 0), OP_EQ, "aaaa.anyone");
  tt_str_op(smartlist_get(out, 1), OP_EQ, "bbbb.anyone");

  /* Counting mode (out == NULL) returns the same count. */
  tt_int_op(anyone_hosts_extract_addresses(doc, NULL), OP_EQ, 2);

 done:
  SMARTLIST_FOREACH(out, char *, s, tor_free(s));
  smartlist_free(out);
}

/* ---- response validation tests ---- */

/* Bodies for the response tests.  Each contains one real mapping line so
 * the has-mappings check passes, plus markers for the mocked verifier. */
#define GOOD_BODY(pub)                                          \
  "anyone-hosts-version 1 SIG=VALID PUB=" #pub " VU=1600000000\n" \
  "map.anyone.anyone dddd.anyone\n"

static void
test_anyone_hosts_update_response_validation(void *arg)
{
  (void)arg;
  char *fname = get_datadir_fname("anyone_hosts");
  char *content = NULL;
  MOCK(anyone_hosts_parse_and_verify_ex, mock_parse_and_verify_ex);
  anyone_hosts_update_init();
  set_update_options(1, 7200);
  tor_unlink(fname);

  /* now == BASE_TIME (1500000000) < VU (1600000000): not expired. */

  /* Non-200 responses are rejected. */
  tt_int_op(anyone_hosts_handle_fetch_response("peer", 503, "busy",
                                               "x", 1, BASE_TIME),
            OP_EQ, -1);

  /* Empty bodies are rejected. */
  tt_int_op(anyone_hosts_handle_fetch_response("peer", 200, "OK",
                                               "", 0, BASE_TIME),
            OP_EQ, -1);

  /* Unsigned bodies are rejected: the signature requirement cannot be
   * configured away. */
  static const char unsigned_body[] =
    "SIG=UNSIGNED\nmap.anyone.anyone dddd.anyone\n";
  tt_int_op(anyone_hosts_handle_fetch_response("peer", 200, "OK",
                                               unsigned_body,
                                               strlen(unsigned_body),
                                               BASE_TIME),
            OP_EQ, -1);
  tt_int_op(file_status(fname), OP_NE, FN_FILE);

  /* Expired documents are rejected. */
  static const char expired_body[] =
    "SIG=VALID VU=1400000000\nmap.anyone.anyone dddd.anyone\n";
  tt_int_op(anyone_hosts_handle_fetch_response("peer", 200, "OK",
                                               expired_body,
                                               strlen(expired_body),
                                               BASE_TIME),
            OP_EQ, -1);

  /* Valid documents with no mapping lines are rejected. */
  static const char no_mappings[] = "SIG=VALID PUB=1500000000\n";
  tt_int_op(anyone_hosts_handle_fetch_response("peer", 200, "OK",
                                               no_mappings,
                                               strlen(no_mappings),
                                               BASE_TIME),
            OP_EQ, -1);
  tt_int_op(file_status(fname), OP_NE, FN_FILE);

  /* A valid, in-date document with mappings is installed. */
  static const char good2[] = GOOD_BODY(1500000200);
  tt_int_op(anyone_hosts_handle_fetch_response("peer", 200, "OK",
                                               good2, strlen(good2),
                                               BASE_TIME),
            OP_EQ, 0);
  content = read_file_to_str(fname, 0, NULL);
  tt_assert(content);
  tt_str_op(content, OP_EQ, good2);
  tor_free(content);

  /* A byte-identical refetch is accepted without rewriting. */
  tt_int_op(anyone_hosts_handle_fetch_response("peer", 200, "OK",
                                               good2, strlen(good2),
                                               BASE_TIME),
            OP_EQ, 0);

  /* A validly signed but OLDER document (replay) is rejected and the
   * installed file is untouched. */
  static const char older[] = GOOD_BODY(1500000100);
  tt_int_op(anyone_hosts_handle_fetch_response("peer", 200, "OK",
                                               older, strlen(older),
                                               BASE_TIME),
            OP_EQ, -1);
  content = read_file_to_str(fname, 0, NULL);
  tt_assert(content);
  tt_str_op(content, OP_EQ, good2);
  tor_free(content);

  /* A NEWER document replaces the installed one. */
  static const char newer[] = GOOD_BODY(1500000300);
  tt_int_op(anyone_hosts_handle_fetch_response("peer", 200, "OK",
                                               newer, strlen(newer),
                                               BASE_TIME),
            OP_EQ, 0);
  content = read_file_to_str(fname, 0, NULL);
  tt_assert(content);
  tt_str_op(content, OP_EQ, newer);

 done:
  tor_free(content);
  if (fname)
    tor_unlink(fname);
  tor_free(fname);
  UNMOCK(anyone_hosts_parse_and_verify_ex);
}

/** The size cap applies to fetched bodies. */
static void
test_anyone_hosts_update_response_size_cap(void *arg)
{
  (void)arg;
  char *fname = get_datadir_fname("anyone_hosts");
  MOCK(anyone_hosts_parse_and_verify_ex, mock_parse_and_verify_ex);
  anyone_hosts_update_init();
  set_update_options(1, 7200);
  tor_unlink(fname);
  get_options_mutable()->DNSMappingFileMaxSize = 16;

  static const char big[] = GOOD_BODY(1500000200);
  tt_assert(strlen(big) > 16);
  tt_int_op(anyone_hosts_handle_fetch_response("peer", 200, "OK",
                                               big, strlen(big), BASE_TIME),
            OP_EQ, -1);
  tt_int_op(file_status(fname), OP_NE, FN_FILE);

 done:
  get_options_mutable()->DNSMappingFileMaxSize = 0;
  if (fname)
    tor_unlink(fname);
  tor_free(fname);
  UNMOCK(anyone_hosts_parse_and_verify_ex);
}

struct testcase_t anyone_hosts_update_tests[] = {
  { "disabled", test_anyone_hosts_update_disabled, TT_FORK, NULL, NULL },
  { "server_mode", test_anyone_hosts_update_server_mode, TT_FORK,
    NULL, NULL },
  { "periodic_launch", test_anyone_hosts_update_periodic_launch, TT_FORK,
    NULL, NULL },
  { "consensus_kick", test_anyone_hosts_update_consensus_kick, TT_FORK,
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
  { "extract_addresses", test_anyone_hosts_update_extract_addresses, TT_FORK,
    NULL, NULL },
  { "response_validation", test_anyone_hosts_update_response_validation,
    TT_FORK, NULL, NULL },
  { "response_size_cap", test_anyone_hosts_update_response_size_cap,
    TT_FORK, NULL, NULL },
  END_OF_TESTCASES
};
