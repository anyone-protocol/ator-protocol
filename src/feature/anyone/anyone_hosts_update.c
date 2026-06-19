/* Copyright (c) 2007-2021, The Tor Project, Inc. */
/* See LICENSE for licensing information */

/**
 * \file anyone_hosts_update.c
 * \brief Periodic and consensus-triggered fetching of the anyone_hosts DNS
 * mapping file from the .anyone DNS service nodes.
 *
 * When the client receives a fresh consensus, or on a periodic schedule,
 * this module selects a URL from the configured list (AnyoneHostsURL) plus
 * the DNS service addresses found in the currently loaded anyone_hosts file
 * and the hardcoded DEFAULT_ANON_DNS_MAPPING, then issues an anonymised
 * HTTP GET for AnyoneHostsFetchPath.  The response is handled by
 * handle_response_fetch_anyone_hosts() in dirclient.c, which verifies the
 * signature and atomically writes the file if acceptable.
 *
 * The fetch is only launched when:
 *   - AnyoneHostsUpdate is set to 1, AND
 *   - no fetch is already in progress, AND
 *   - at least AnyoneHostsUpdateInterval seconds have elapsed since the last
 *     successful fetch (and we additionally wait at least
 *     ANYONE_HOSTS_MIN_RETRY_INTERVAL between attempts before the first
 *     success).
 **/

#include "core/or/or.h"
#include "feature/anyone/anyone_hosts_update.h"
#include "feature/dircommon/directory.h"
#include "feature/dirclient/dirclient.h"
#include "app/config/config.h"
#include "lib/log/log.h"
#include "lib/malloc/malloc.h"
#include "lib/container/smartlist.h"
#include "lib/string/util_string.h"
#include "lib/encoding/confline.h"
#include "lib/fs/files.h"

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#endif

/** Minimum gap between consecutive fetch *attempts* (seconds). */
#define ANYONE_HOSTS_MIN_RETRY_INTERVAL 3600

/** If a fetch has been "in progress" for at least this many seconds without
 * reporting a result, assume it failed on a path that did not notify us and
 * clear the flag so future updates are not blocked. */
#define ANYONE_HOSTS_FETCH_TIMEOUT 600

/** True while a DIR_PURPOSE_FETCH_ANYONE_HOSTS connection is open. */
static int fetch_in_progress = 0;

/** Monotone wall-clock time of the last fetch attempt. */
static time_t last_attempt_time = 0;

/** Monotone wall-clock time of the last *successful* fetch. */
static time_t last_success_time = 0;

/** Round-robin index into the URL list. */
static int current_url_index = 0;

/** ---------- helpers ---------- */

/**
 * Build an ordered smartlist of onion-address strings to try for fetching
 * the anyone_hosts file.  Caller must free each element and the list.
 *
 * Order: AnyoneHostsURL config entries (user overrides) first, then the
 * right-hand-side addresses from the currently saved anyone_hosts file,
 * then addresses from DEFAULT_ANON_DNS_MAPPING.  Duplicates are kept so
 * that the round-robin stays predictable.
 */
static smartlist_t *
anyone_hosts_get_url_list(void)
{
  smartlist_t *urls = smartlist_new();
  const or_options_t *options = get_options();

  /* 1. User-configured overrides. */
  for (const config_line_t *cl = options->AnyoneHostsURL; cl; cl = cl->next) {
    if (cl->value && strlen(cl->value))
      smartlist_add(urls, tor_strdup(cl->value));
  }

  /* Helper: parse lines of the form "<hostname> <onion-address>" and
   * add the onion address to <urls>.  Only accept right-hand-side tokens
   * that look like .anyone addresses, and skip metadata lines from the
   * signed file format (e.g. "anyone-hosts-version 1",
   * "anyone-hosts-digest sha256 ...", "anyone-hosts-signature <signer>")
   * whose first token starts with "anyone-hosts-" -- even if their second
   * token happens to end in ".anyone". */
#define ADD_MAPPING_LINES(text)                                         \
  do {                                                                  \
    smartlist_t *_lines = smartlist_new();                              \
    char *_copy = tor_strdup(text);                                     \
    smartlist_split_string(_lines, _copy, "\n", SPLIT_SKIP_SPACE, 0);  \
    SMARTLIST_FOREACH_BEGIN(_lines, const char *, _line) {              \
      const char *_sp = strchr(_line, ' ');                             \
      if (_sp && *(_sp + 1) &&                                          \
          strcmpstart(_line, "anyone-hosts-") != 0) {                   \
        const char *_addr = _sp + 1;                                    \
        size_t _alen = strlen(_addr);                                   \
        if (_alen >= 7 && !strcmp(_addr + _alen - 7, ".anyone"))        \
          smartlist_add(urls, tor_strdup(_addr));                       \
      }                                                                 \
    } SMARTLIST_FOREACH_END(_line);                                     \
    SMARTLIST_FOREACH(_lines, char *, _s, tor_free(_s));                \
    smartlist_free(_lines);                                             \
    tor_free(_copy);                                                    \
  } while (0)

  /* 2. Addresses from the currently saved anyone_hosts file.  Cap the read
   * at DNSMappingFileMaxSize so a large or hostile local file cannot cause
   * excessive memory use here, matching the cap that lookups use. */
  char *hosts_fname = get_datadir_fname("anyone_hosts");
  int hosts_fd = tor_open_cloexec(hosts_fname, O_RDONLY, 0);
  tor_free(hosts_fname);
  if (hosts_fd >= 0) {
    const uint64_t max_size_opt = options->DNSMappingFileMaxSize;
    const size_t max_size = max_size_opt == 0 ? SIZE_T_CEILING :
      (max_size_opt > SIZE_T_CEILING ? SIZE_T_CEILING : (size_t)max_size_opt);
    size_t hosts_sz = 0;
    char *hosts_content =
      read_file_to_str_until_eof(hosts_fd, max_size, &hosts_sz);
    close(hosts_fd);
    if (hosts_content) {
      ADD_MAPPING_LINES(hosts_content);
      tor_free(hosts_content);
    }
  }

  /* 3. Hardcoded defaults as a last resort. */
  ADD_MAPPING_LINES(DEFAULT_ANON_DNS_MAPPING);

#undef ADD_MAPPING_LINES

  return urls;
}

/** ---------- public API ---------- */

void
anyone_hosts_update_init(void)
{
  fetch_in_progress = 0;
  last_attempt_time = 0;
  last_success_time = 0;
  current_url_index = 0;
}

void
anyone_hosts_update_free_all(void)
{
  fetch_in_progress = 0;
}

/** Called by dirclient when a DIR_PURPOSE_FETCH_ANYONE_HOSTS connection
 * completes (successfully or not).  This clears the in-progress flag and,
 * on success, records the current time so the interval timer resets. */
void
anyone_hosts_update_note_result(int success, time_t now)
{
  /* Be idempotent within a single fetch: the response handler and the
   * connection-failure path can both call this, so only the first call for a
   * given fetch records a result (and advances the round-robin index). */
  if (!fetch_in_progress)
    return;
  fetch_in_progress = 0;
  if (success)
    last_success_time = now;
  /* Advance the index so the next attempt tries a different server, whether
   * or not this one succeeded.  This keeps the ordered fallback / round-robin
   * working even when the first entry is permanently unreachable. */
  current_url_index++;
}

/**
 * Launch one fetch if conditions are met.  Called both from the consensus
 * hook (anyone_hosts_update_maybe_kick) and from the periodic callback.
 */
static void
maybe_launch_fetch(time_t now)
{
  const or_options_t *options = get_options();

  if (!options->AnyoneHostsUpdate)
    return;
  if (fetch_in_progress) {
    /* Safety net: a previous fetch may have failed on a path that never
     * called anyone_hosts_update_note_result().  Don't stay stuck forever. */
    if (last_attempt_time &&
        (now - last_attempt_time) >= ANYONE_HOSTS_FETCH_TIMEOUT) {
      log_info(LD_DIR, "anyone_hosts fetch appears stuck; resetting state.");
      fetch_in_progress = 0;
    } else {
      return;
    }
  }

  /* Respect the configured update interval for successes. */
  if (last_success_time &&
      (now - last_success_time) < options->AnyoneHostsUpdateInterval)
    return;

  /* After a failed attempt wait at least ANYONE_HOSTS_MIN_RETRY_INTERVAL
   * before trying again, regardless of the configured interval.  We treat
   * the last attempt as a failure if it happened after the last success, so
   * the backoff also applies to failures that occur after an earlier success
   * (preventing a rapid retry storm). */
  if (last_attempt_time && last_attempt_time > last_success_time &&
      (now - last_attempt_time) < ANYONE_HOSTS_MIN_RETRY_INTERVAL)
    return;

  /* Pick the next URL from the list. */
  smartlist_t *urls = anyone_hosts_get_url_list();
  if (smartlist_len(urls) == 0) {
    log_info(LD_DIR, "anyone_hosts update: no URLs available.");
    SMARTLIST_FOREACH(urls, char *, u, tor_free(u));
    smartlist_free(urls);
    return;
  }

  int idx = current_url_index % smartlist_len(urls);
  const char *onion_addr = smartlist_get(urls, idx);

  log_info(LD_DIR, "Launching anyone_hosts fetch from %s", onion_addr);

  /* Build and fire the directory request.  The connection is anonymised
   * (purpose_needs_anonymity returns 1 for DIR_PURPOSE_FETCH_ANYONE_HOSTS)
   * and tunnelled through a 3-hop circuit to the .anyone DNS service, which
   * serves the file over plain HTTP on port 80. */
  directory_request_t *req =
    directory_request_new(DIR_PURPOSE_FETCH_ANYONE_HOSTS);
  directory_request_set_indirection(req, DIRIND_ANONYMOUS);

  /* Route to the onion address by name rather than by IP.  We set the
   * dir-port to 80 (with no or-port) so the request is sent as a plain
   * anonymised stream rather than a begindir tunnel, and supply the
   * .anyone address explicitly. */
  tor_addr_port_t dirport;
  memset(&dirport, 0, sizeof(dirport));
  tor_addr_make_null(&dirport.addr, AF_INET);
  dirport.port = 80;
  directory_request_set_dir_addr_port(req, &dirport);
  directory_request_set_anon_onion_address(req, onion_addr);

  /* The HTTP resource (path) to request from the DNS service. */
  directory_request_set_resource(req, options->AnyoneHostsFetchPath);

  /* A directory request requires an identity digest; it is unused for an
   * anonymised onion-address fetch, so pass a zero placeholder. */
  static const char zero_digest[DIGEST_LEN] = {0};
  directory_request_set_directory_id_digest(req, zero_digest);

  fetch_in_progress = 1;
  last_attempt_time = now;

  directory_initiate_request(req);
  directory_request_free(req);

  SMARTLIST_FOREACH(urls, char *, u, tor_free(u));
  smartlist_free(urls);
}

void
anyone_hosts_update_maybe_kick(time_t now)
{
  const or_options_t *options = get_options();
  if (!options->AnyoneHostsUpdateTrigger)
    return;
  const char *t = options->AnyoneHostsUpdateTrigger;
  if (strcmp(t, "consensus") != 0 && strcmp(t, "both") != 0)
    return;

  maybe_launch_fetch(now);
}

int
anyone_hosts_update_callback(time_t now, const or_options_t *options)
{
  if (!options->AnyoneHostsUpdateTrigger)
    return options->AnyoneHostsUpdateInterval;
  const char *t = options->AnyoneHostsUpdateTrigger;
  if (strcmp(t, "periodic") != 0 && strcmp(t, "both") != 0)
    return options->AnyoneHostsUpdateInterval;

  maybe_launch_fetch(now);
  return options->AnyoneHostsUpdateInterval;
}
