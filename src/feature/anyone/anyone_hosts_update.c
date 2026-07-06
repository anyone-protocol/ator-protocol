/* Copyright (c) 2007-2021, The Tor Project, Inc. */
/* See LICENSE for licensing information */

/**
 * \file anyone_hosts_update.c
 * \brief Periodic and consensus-triggered fetching of the anyone_hosts DNS
 * mapping file from the .anyone DNS service nodes.
 *
 * When the client receives a fresh consensus, or on a periodic schedule,
 * this module selects a target from the configured AnyoneHostsURL list
 * (falling back to the DNS service addresses in DEFAULT_ANON_DNS_MAPPING)
 * and issues an anonymised HTTP GET for ANYONE_HOSTS_FETCH_PATH.  The
 * request is routed to the target by .anyone name, over a hidden-service
 * circuit, through the same rewrite path client SOCKS streams use.
 *
 * A fetched file is installed only when all of the following hold:
 *   - it is non-empty, within DNSMappingFileMaxSize, and carries a valid
 *     signature from a trusted DNS signer (there is deliberately no
 *     configuration to weaken the signature requirement),
 *   - its valid-until time, when present, has not passed, and
 *   - it is not older (by published time) than the installed mapping.
 *
 * A fetch is only launched when AnyoneHostsUpdate is enabled, no fetch is
 * already in progress, at least AnyoneHostsUpdateInterval seconds have
 * elapsed since the last accepted file, and at least
 * ANYONE_HOSTS_MIN_RETRY_INTERVAL seconds have elapsed since a failed
 * attempt.
 **/

#include "core/or/or.h"
#include "feature/anyone/anyone_hosts_update.h"
#include "feature/dircommon/directory.h"
#include "feature/dirclient/dirclient.h"
#include "feature/dirparse/anyone_hosts_parse.h"
#include "feature/relay/routermode.h"
#include "app/config/config.h"
#include "lib/crypt_ops/crypto_rand.h"
#include "lib/encoding/confline.h"
#include "lib/fs/files.h"
#include "lib/log/escape.h"

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#endif

/** Minimum gap between fetch attempts after a failure (seconds). */
#define ANYONE_HOSTS_MIN_RETRY_INTERVAL 3600

/** If a fetch has been "in progress" for at least this many seconds without
 * reporting a result, assume it failed on a path that did not notify us and
 * clear the flag so future updates are not blocked. */
#define ANYONE_HOSTS_FETCH_TIMEOUT 600

/** True while a DIR_PURPOSE_FETCH_ANYONE_HOSTS connection is open. */
static int fetch_in_progress = 0;

/** Wall-clock time of the last fetch attempt. */
static time_t last_attempt_time = 0;

/** Wall-clock time of the last *accepted* fetch. */
static time_t last_success_time = 0;

/** Index into the target list; advanced only when an attempt fails, so a
 * working server keeps serving future updates. */
static int current_url_index = 0;

/** ---------- helpers ---------- */

/**
 * Scan <b>text</b> (mapping-file format) and, for every mapping line
 * "<name> <onion-address>" whose address ends in ".anyone", append a copy
 * of the address to <b>out</b> (if non-NULL).  Metadata lines of the signed
 * format (anyone-hosts-*, published, valid-until, PEM markers) are skipped.
 * Return the number of addresses found.
 */
STATIC int
anyone_hosts_extract_addresses(const char *text, smartlist_t *out)
{
  int n_found = 0;
  smartlist_t *lines = smartlist_new();
  char *copy = tor_strdup(text);
  smartlist_split_string(lines, copy, "\n", SPLIT_SKIP_SPACE, 0);

  SMARTLIST_FOREACH_BEGIN(lines, const char *, line) {
    if (!strcmpstart(line, "anyone-hosts-") ||
        !strcmpstart(line, "published") ||
        !strcmpstart(line, "valid-until") ||
        !strcmpstart(line, "-----"))
      continue;
    const char *addr = eat_whitespace_no_nl(find_whitespace(line));
    if (*addr && !strcmpend(addr, ".anyone")) {
      if (out)
        smartlist_add(out, tor_strdup(addr));
      ++n_found;
    }
  } SMARTLIST_FOREACH_END(line);

  SMARTLIST_FOREACH(lines, char *, s, tor_free(s));
  smartlist_free(lines);
  tor_free(copy);
  return n_found;
}

/**
 * Build an ordered smartlist of onion-address strings to try for fetching
 * the anyone_hosts file: AnyoneHostsURL config entries (user overrides)
 * first, then the addresses from DEFAULT_ANON_DNS_MAPPING.  Caller must
 * free each element and the list.
 */
static smartlist_t *
anyone_hosts_get_url_list(void)
{
  smartlist_t *urls = smartlist_new();
  const or_options_t *options = get_options();

  for (const config_line_t *cl = options->AnyoneHostsURL; cl; cl = cl->next) {
    if (cl->value && strlen(cl->value))
      smartlist_add(urls, tor_strdup(cl->value));
  }

  anyone_hosts_extract_addresses(DEFAULT_ANON_DNS_MAPPING, urls);

  return urls;
}

/** Return true iff auto-updating is enabled for this configuration.
 * Relays can also have the CLIENT role (e.g. when ControlPort is set), but
 * anyone_hosts auto-update is intended for actual clients only. */
static int
update_is_enabled(const or_options_t *options)
{
  return options->AnyoneHostsUpdate && !server_mode(options);
}

/** Read the currently installed anyone_hosts file into a newly allocated
 * string, or return NULL if it is missing or unreadable.  Applies the
 * DNSMappingFileMaxSize read cap, treating 0 as "no limit". */
static char *
read_installed_hosts_file(size_t *sz_out)
{
  const or_options_t *options = get_options();
  char *fname = get_datadir_fname("anyone_hosts");
  int fd = tor_open_cloexec(fname, O_RDONLY, 0);
  tor_free(fname);
  if (fd < 0)
    return NULL;
  const uint64_t max_size_opt = options->DNSMappingFileMaxSize;
  /* read_file_to_str_until_eof() rejects a limit of SIZE_T_CEILING or more,
   * so keep the effective "no cap" value just below that boundary. */
  const size_t max_read_cap = SIZE_T_CEILING - 2;
  const size_t max_size = (max_size_opt == 0 || max_size_opt > max_read_cap)
    ? max_read_cap : (size_t)max_size_opt;
  char *content = read_file_to_str_until_eof(fd, max_size, sz_out);
  close(fd);
  return content;
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

/** Called when a DIR_PURPOSE_FETCH_ANYONE_HOSTS fetch completes
 * (successfully or not).  Clears the in-progress flag; on success records
 * the time so the interval timer resets, on failure advances the target
 * index so the next attempt tries a different server. */
void
anyone_hosts_update_note_result(int success, time_t now)
{
  /* Be idempotent within a single fetch: the response handler and the
   * connection-failure path can both call this, so only the first call for
   * a given fetch records a result. */
  if (!fetch_in_progress)
    return;
  fetch_in_progress = 0;
  if (success)
    last_success_time = now;
  else
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

  if (!update_is_enabled(options))
    return;
  if (fetch_in_progress) {
    /* Safety net: directory_initiate_request() returns void and can fail
     * before any connection exists, in which case nothing ever calls
     * anyone_hosts_update_note_result().  Don't stay stuck forever.
     * (Don't fall through to launch a new fetch here: a live connection
     * may still call note_result() later.) */
    if (last_attempt_time &&
        (now - last_attempt_time) >= ANYONE_HOSTS_FETCH_TIMEOUT) {
      log_info(LD_DIR,
               "anyone_hosts fetch appears stuck; treating as failed.");
      anyone_hosts_update_note_result(0, now);
    }
    return;
  }

  /* Respect the configured update interval after an accepted fetch. */
  if (last_success_time &&
      (now - last_success_time) < options->AnyoneHostsUpdateInterval)
    return;

  /* After a failed attempt wait at least ANYONE_HOSTS_MIN_RETRY_INTERVAL
   * before trying again, regardless of the configured interval. */
  if (last_attempt_time && last_attempt_time > last_success_time &&
      (now - last_attempt_time) < ANYONE_HOSTS_MIN_RETRY_INTERVAL)
    return;

  smartlist_t *urls = anyone_hosts_get_url_list();
  if (smartlist_len(urls) == 0) {
    log_info(LD_DIR, "anyone_hosts update: no target addresses available.");
    smartlist_free(urls);
    return;
  }

  int idx = current_url_index % smartlist_len(urls);
  const char *onion_addr = smartlist_get(urls, idx);

  log_info(LD_DIR, "Launching anyone_hosts fetch from %s",
           safe_str(onion_addr));

  /* Build and fire the directory request.  The connection is anonymised
   * (purpose_needs_anonymity returns 1 for DIR_PURPOSE_FETCH_ANYONE_HOSTS)
   * and routed by .anyone name over a hidden-service circuit; the DNS
   * service serves the file over HTTP on port 80 behind its onion
   * service. */
  directory_request_t *req =
    directory_request_new(DIR_PURPOSE_FETCH_ANYONE_HOSTS);
  directory_request_set_indirection(req, DIRIND_ANONYMOUS);

  tor_addr_port_t dirport;
  memset(&dirport, 0, sizeof(dirport));
  tor_addr_make_null(&dirport.addr, AF_INET);
  dirport.port = 80;
  directory_request_set_dir_addr_port(req, &dirport);
  directory_request_set_anon_onion_address(req, onion_addr);
  directory_request_set_resource(req, ANYONE_HOSTS_FETCH_PATH);

  /* A directory request requires an identity digest; it is unused for a
   * name-routed onion fetch, so pass a zero placeholder. */
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
  maybe_launch_fetch(now);
}

int
anyone_hosts_update_callback(time_t now, const or_options_t *options)
{
  int interval = options->AnyoneHostsUpdateInterval;

  maybe_launch_fetch(now);

  /* Jitter the next run by up to +/-10% so identically configured clients
   * do not fetch in lockstep. */
  int jitter = interval / 10;
  if (jitter > 0)
    interval += crypto_rand_int((unsigned)(2 * jitter + 1)) - jitter;
  return interval;
}

/** Validate the body of a fetch response and atomically install it as the
 * new anyone_hosts file if acceptable.  <b>peer_desc</b> describes the
 * server for log messages.  Returns 0 if the file was accepted (including
 * the case where it was identical to the installed file), -1 otherwise. */
int
anyone_hosts_handle_fetch_response(const char *peer_desc, int status_code,
                                   const char *reason,
                                   const char *body, size_t body_len,
                                   time_t now)
{
  const or_options_t *options = get_options();
  int success = 0;

  if (status_code != 200) {
    log_info(LD_DIR,
             "Received http status code %d (%s) from server %s while "
             "fetching anyone_hosts file.",
             status_code, escaped(reason), peer_desc);
    goto done;
  }

  if (!body || body_len == 0) {
    log_warn(LD_DIR, "anyone_hosts file from %s is empty; discarding.",
             peer_desc);
    goto done;
  }

  if (options->DNSMappingFileMaxSize > 0 &&
      body_len > options->DNSMappingFileMaxSize) {
    log_warn(LD_DIR, "anyone_hosts file from %s is too large (%"TOR_PRIuSZ
             " bytes, limit %"PRIu64"); discarding.",
             peer_desc, body_len, options->DNSMappingFileMaxSize);
    goto done;
  }

  /* The fetched file must carry a valid signature from a trusted DNS
   * signer.  There is deliberately no configuration to weaken this: an
   * unsigned or badly signed mapping would let whichever node served the
   * fetch rewrite every .anyone name. */
  time_t published = 0, valid_until = 0;
  anyone_hosts_sig_status_t sig =
    anyone_hosts_parse_and_verify_ex(body, body_len,
                                     &published, &valid_until);
  if (sig != ANYONE_HOSTS_SIG_VALID) {
    log_warn(LD_DIR, "anyone_hosts file from %s: signature check failed "
             "(status %d); discarding.", peer_desc, (int)sig);
    goto done;
  }

  if (valid_until && valid_until < now) {
    log_warn(LD_DIR, "anyone_hosts file from %s expired %ld seconds ago; "
             "discarding.", peer_desc, (long)(now - valid_until));
    goto done;
  }

  /* Require at least one mapping so a signed-but-empty document cannot
   * wipe the installed file. */
  if (anyone_hosts_extract_addresses(body, NULL) == 0) {
    log_warn(LD_DIR, "anyone_hosts file from %s contains no mappings; "
             "discarding.", peer_desc);
    goto done;
  }

  /* Compare against the installed file: skip byte-identical rewrites, and
   * refuse to replace a newer installed mapping with an older one, so a
   * replayed (validly signed but stale) file cannot roll the mapping
   * back. */
  {
    size_t cur_len = 0;
    char *cur = read_installed_hosts_file(&cur_len);
    if (cur) {
      if (cur_len == body_len && memcmp(cur, body, body_len) == 0) {
        log_info(LD_DIR, "anyone_hosts file from %s is unchanged.",
                 peer_desc);
        tor_free(cur);
        success = 1;
        goto done;
      }
      time_t cur_published = 0;
      (void) anyone_hosts_parse_and_verify_ex(cur, cur_len,
                                              &cur_published, NULL);
      tor_free(cur);
      if (cur_published && published && published < cur_published) {
        log_warn(LD_DIR, "anyone_hosts file from %s is older than the "
                 "installed mapping (published %ld < %ld); discarding.",
                 peer_desc, (long)published, (long)cur_published);
        goto done;
      }
    }
  }

  /* write_bytes_to_file() writes atomically via its own temp file + rename,
   * so write the verified bytes straight to the final path. */
  {
    char *hosts_fname = get_datadir_fname("anyone_hosts");
    int write_ok = (write_bytes_to_file(hosts_fname, body, body_len, 1) == 0);
    tor_free(hosts_fname);
    if (!write_ok) {
      log_warn(LD_FS, "Error writing anyone_hosts file.");
      goto done;
    }
  }

  log_info(LD_DIR, "Successfully updated anyone_hosts file (%"TOR_PRIuSZ
           " bytes).", body_len);
  success = 1;

 done:
  anyone_hosts_update_note_result(success, now);
  return success ? 0 : -1;
}
