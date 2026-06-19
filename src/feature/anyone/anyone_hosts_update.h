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

/** Initialize the anyone_hosts update subsystem. */
void anyone_hosts_update_init(void);

/** Free any state held by the anyone_hosts update subsystem. */
void anyone_hosts_update_free_all(void);

/** Called after a consensus is successfully loaded; may kick off a fetch
 * if the configuration and timing allow it. */
void anyone_hosts_update_maybe_kick(time_t now);

/** Called by dirclient when a DIR_PURPOSE_FETCH_ANYONE_HOSTS fetch
 * completes.  <b>success</b> is 1 if the file was saved, 0 otherwise. */
void anyone_hosts_update_note_result(int success, time_t now);

/** Periodic-event callback: try to fetch a fresh anyone_hosts file. */
int anyone_hosts_update_callback(time_t now,
                                 const struct or_options_t *options);

#endif /* !defined(TOR_ANYONE_HOSTS_UPDATE_H) */
