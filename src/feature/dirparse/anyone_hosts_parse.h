/**
 * \file anyone_hosts_parse.h
 * \brief Header for anyone_hosts_parse.c
 **/

#ifndef TOR_ANYONE_HOSTS_PARSE_H
#define TOR_ANYONE_HOSTS_PARSE_H

/** Result of verifying an anyone_hosts file signature. */
typedef enum {
  ANYONE_HOSTS_SIG_VALID = 0,
  ANYONE_HOSTS_SIG_INVALID,
  ANYONE_HOSTS_SIG_UNSIGNED,
  ANYONE_HOSTS_SIG_BAD_SIGNER,
  ANYONE_HOSTS_SIG_PARSE_ERROR,
} anyone_hosts_sig_status_t;

/** Domain-separation prefix for ed25519 signing of anyone_hosts files. */
#define ANYONE_HOSTS_SIGN_PREFIX "anyone-hosts-signature"

anyone_hosts_sig_status_t anyone_hosts_parse_and_verify(const char *body,
                                                        size_t body_len);

#endif /* !defined(TOR_ANYONE_HOSTS_PARSE_H) */
