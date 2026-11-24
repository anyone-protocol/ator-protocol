/* Copyright (c) 2007-2021, The Tor Project, Inc. */
/* See LICENSE for licensing information */

/**
 * \file anyone_hosts_update.h
 * \brief Header for anyone_hosts_update.c
 *
 * Periodic and consensus-triggered fetching of the anyone_hosts DNS
 * mapping file from the .anyone DNS service nodes.
 **/

#ifndef TOR_ANYONE_HOSTS_UPDATE_H
#define TOR_ANYONE_HOSTS_UPDATE_H

#include "lib/testsupport/testsupport.h"
#include <stddef.h>
#include <time.h>

struct or_options_t;
struct smartlist_t;

/** HTTP resource path requested from the DNS service nodes. */
#define ANYONE_HOSTS_FETCH_PATH "/tld/anyone"

/** Initialize (or reset) the anyone_hosts update subsystem state. */
void anyone_hosts_update_init(void);

/** Called after a consensus is successfully loaded; may kick off a fetch
 * if configuration and timing allow it. */
void anyone_hosts_update_maybe_kick(time_t now);

/** Called when a DIR_PURPOSE_FETCH_ANYONE_HOSTS fetch completes.
 * <b>success</b> is 1 if a file was accepted, 0 otherwise. */
void anyone_hosts_update_note_result(int success, time_t now);

/** Periodic-event callback: try to fetch a fresh anyone_hosts file.
 * Returns the number of seconds until the next run. */
int anyone_hosts_update_callback(time_t now,
                                 const struct or_options_t *options);

/** Validate and install the body of a fetch response.  Returns 0 if the
 * file was accepted, -1 otherwise.  Reports the outcome to the scheduler
 * via anyone_hosts_update_note_result(). */
int anyone_hosts_handle_fetch_response(const char *peer_desc,
                                       int status_code, const char *reason,
                                       const char *body, size_t body_len,
                                       time_t now);

#ifdef ANYONE_HOSTS_UPDATE_PRIVATE
STATIC int anyone_hosts_extract_addresses(const char *text,
                                          struct smartlist_t *out);
#endif

#endif /* !defined(TOR_ANYONE_HOSTS_UPDATE_H) */
