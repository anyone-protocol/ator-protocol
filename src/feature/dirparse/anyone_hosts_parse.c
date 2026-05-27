/**
 * \file anyone_hosts_parse.c
 * \brief Parsing and signature verification for signed anyone_hosts files.
 *
 * The signed anyone_hosts file format follows the consensus document
 * conventions with anyone-hosts-prefixed keywords:
 *
 *   anyone-hosts-version 1
 *   anyone-hosts-status signed
 *   published YYYY-MM-DD HH:MM:SS
 *   valid-until YYYY-MM-DD HH:MM:SS
 *
 *   dns-live-1.anyone.anyone <56-char-base32>.anyone
 *   dns-live-2.anyone.anyone <56-char-base32>.anyone
 *
 *   anyone-hosts-digest sha256 <64-char hex>
 *   anyone-hosts-signature <signer .anyone address>
 *   -----BEGIN SIGNATURE-----
 *   <base64 ed25519 signature>
 *   -----END SIGNATURE-----
 *
 * The signed region covers everything from "anyone-hosts-version" through
 * the end of the "anyone-hosts-signature" line (including \n), matching
 * the consensus hash boundary pattern. The PEM signature block is appended
 * after the signed region.
 *
 * The anyone-hosts-digest field contains a SHA-256 hash of just the sorted
 * mapping lines, providing a quick integrity check.
 *
 * The signer's ed25519 public key is extracted from their .anyone address
 * via hs_parse_address(). Trust is anchored to the hardcoded DNS service
 * addresses in DEFAULT_ANON_DNS_MAPPING.
 **/

#include "core/or/or.h"
#include "feature/dirparse/anyone_hosts_parse.h"
#include "feature/dirparse/parsecommon.h"
#include "feature/dirparse/sigcommon.h"
#include "feature/hs/hs_common.h"
#include "app/config/config.h"
#include "lib/memarea/memarea.h"
#include "lib/container/smartlist.h"
#include "lib/crypt_ops/crypto_digest.h"
#include "lib/crypt_ops/crypto_ed25519.h"
#include "lib/crypt_ops/crypto_format.h"
#include "lib/encoding/binascii.h"
#include "lib/string/util_string.h"
#include "lib/log/util_bug.h"

/** Token table for signed anyone_hosts documents. */
// clang-format off
static token_rule_t anyone_hosts_token_table[] = {
  T1_START( "anyone-hosts-version",   K_ANYONE_HOSTS_VERSION,   EQ(1),       NO_OBJ ),
  T01(      "anyone-hosts-status",    K_ANYONE_HOSTS_STATUS,    EQ(1),       NO_OBJ ),
  T01(      "published",              K_PUBLISHED,              CONCAT_ARGS, NO_OBJ ),
  T01(      "valid-until",            K_VALID_UNTIL,            CONCAT_ARGS, NO_OBJ ),
  T01(      "anyone-hosts-digest",    K_ANYONE_HOSTS_DIGEST,    EQ(2),       NO_OBJ ),
  T1_END(   "anyone-hosts-signature", K_ANYONE_HOSTS_SIGNATURE, GE(1),       NEED_OBJ ),
  END_OF_TABLE
};
// clang-format on

/** Return true if <b>signer_address</b> is one of the trusted DNS service
 * addresses hardcoded in DEFAULT_ANON_DNS_MAPPING. */
static bool
is_trusted_dns_signer(const char *signer_address)
{
  bool found = false;
  char *defaults = tor_strdup(DEFAULT_ANON_DNS_MAPPING);
  smartlist_t *lines = smartlist_new();
  smartlist_split_string(lines, defaults, "\n", SPLIT_SKIP_SPACE, 0);

  SMARTLIST_FOREACH_BEGIN(lines, const char *, line) {
    /* Each line is "<name> <onion-address>". Check the onion address part. */
    const char *space = strchr(line, ' ');
    if (space) {
      const char *onion_addr = space + 1;
      if (strcmp(onion_addr, signer_address) == 0) {
        found = true;
        break;
      }
    }
  } SMARTLIST_FOREACH_END(line);

  SMARTLIST_FOREACH(lines, char *, s, tor_free(s));
  smartlist_free(lines);
  tor_free(defaults);
  return found;
}

/** Parse and verify the signature on a signed anyone_hosts file.
 *
 * <b>body</b> is the full file content, <b>body_len</b> is its length.
 *
 * Returns:
 *   ANYONE_HOSTS_SIG_VALID       — signature verified successfully
 *   ANYONE_HOSTS_SIG_INVALID     — signature present but verification failed
 *   ANYONE_HOSTS_SIG_UNSIGNED    — no signature metadata found
 *   ANYONE_HOSTS_SIG_BAD_SIGNER  — signer is not a trusted DNS service
 *   ANYONE_HOSTS_SIG_PARSE_ERROR — file has signature headers but is malformed
 */
anyone_hosts_sig_status_t
anyone_hosts_parse_and_verify(const char *body, size_t body_len)
{
  smartlist_t *tokens = NULL;
  memarea_t *area = NULL;
  directory_token_t *tok;
  char digest[DIGEST256_LEN];
  anyone_hosts_sig_status_t result = ANYONE_HOSTS_SIG_PARSE_ERROR;

  tor_assert(body);

  /* Quick check: if the file doesn't start with our version keyword,
   * it's an unsigned plain-text file (backward compatible). */
  if (body_len < strlen("anyone-hosts-version") ||
      strcmpstart(body, "anyone-hosts-version") != 0) {
    return ANYONE_HOSTS_SIG_UNSIGNED;
  }

  tokens = smartlist_new();
  area = memarea_new();

  /* Tokenize the document. We use TS_NOCHECK to tolerate the mapping lines
   * which will be parsed as K_OPT tokens. */
  if (tokenize_string(area, body, body + body_len, tokens,
                      anyone_hosts_token_table, TS_NOCHECK) < 0) {
    log_warn(LD_DIR, "Error tokenizing anyone_hosts file.");
    goto done;
  }

  /* Verify the version. */
  tok = find_opt_by_keyword(tokens, K_ANYONE_HOSTS_VERSION);
  if (!tok || strcmp(tok->args[0], "1") != 0) {
    log_warn(LD_DIR, "anyone_hosts: unrecognized or missing version.");
    goto done;
  }

  /* Find the signature token. */
  tok = find_opt_by_keyword(tokens, K_ANYONE_HOSTS_SIGNATURE);
  if (!tok) {
    result = ANYONE_HOSTS_SIG_UNSIGNED;
    goto done;
  }

  /* The signer's .anyone address is the first argument. */
  if (tok->n_args < 1) {
    log_warn(LD_DIR, "anyone_hosts: missing signer address on "
             "anyone-hosts-signature line.");
    goto done;
  }
  const char *signer_address = tok->args[0];

  /* Verify signer is a trusted DNS service. */
  if (!is_trusted_dns_signer(signer_address)) {
    log_warn(LD_DIR, "anyone_hosts: signer %s is not a trusted DNS service.",
             signer_address);
    result = ANYONE_HOSTS_SIG_BAD_SIGNER;
    goto done;
  }

  /* Extract the ed25519 public key from the signer's .anyone address.
   * hs_parse_address expects the base32 address WITHOUT the .anyone suffix. */
  ed25519_public_key_t signer_pubkey;
  char signer_base32[HS_SERVICE_ADDR_LEN_BASE32 + 1];
  size_t signer_len = strlen(signer_address);
  if (signer_len != HS_SERVICE_ADDR_LENGTH_WITH_SUFFIX ||
      strcmpend(signer_address, HS_SERVICE_ADDR_SUFFIX) != 0) {
    log_warn(LD_DIR, "anyone_hosts: signer address %s has wrong format.",
             signer_address);
    goto done;
  }
  strlcpy(signer_base32, signer_address,
          signer_len - HS_SERVICE_ADDR_SUFFIX_LENGTH + 1);
  if (hs_parse_address(signer_base32, &signer_pubkey, NULL, NULL) < 0) {
    log_warn(LD_DIR, "anyone_hosts: could not parse signer address %s.",
             signer_address);
    goto done;
  }

  /* Extract the raw signature from the PEM object body.
   * The tokenizer has already base64-decoded the PEM block for us. */
  if (!tok->object_body || tok->object_size != ED25519_SIG_LEN) {
    log_warn(LD_DIR, "anyone_hosts: signature object has wrong size "
             "(got %lu, expected %d).",
             (unsigned long)tok->object_size, ED25519_SIG_LEN);
    goto done;
  }
  ed25519_signature_t sig;
  memcpy(sig.sig, tok->object_body, ED25519_SIG_LEN);

  /* Compute the hash over the signed region:
   * from "anyone-hosts-version" through "anyone-hosts-signature ...\n" */
  if (router_get_hash_impl(body, body_len, digest,
                           "anyone-hosts-version",
                           "\nanyone-hosts-signature",
                           '\n', DIGEST_SHA256) < 0) {
    log_warn(LD_DIR, "anyone_hosts: could not compute document hash.");
    goto done;
  }

  /* Verify the ed25519 signature over the hash.
   * Use a domain-separation prefix to prevent cross-protocol attacks. */
  if (ed25519_checksig_prefixed(&sig,
                                (const uint8_t *)digest, DIGEST256_LEN,
                                ANYONE_HOSTS_SIGN_PREFIX,
                                &signer_pubkey) != 0) {
    log_warn(LD_DIR, "anyone_hosts: signature verification failed.");
    result = ANYONE_HOSTS_SIG_INVALID;
    goto done;
  }

  /* Optionally verify the anyone-hosts-digest field if present. */
  tok = find_opt_by_keyword(tokens, K_ANYONE_HOSTS_DIGEST);
  if (tok && tok->n_args >= 2) {
    if (strcmp(tok->args[0], "sha256") != 0) {
      log_warn(LD_DIR, "anyone_hosts: unsupported digest algorithm %s.",
               tok->args[0]);
      /* Not fatal — the signature already verified. */
    } else {
      /* Collect mapping lines (K_OPT tokens), sort, join, and hash. */
      smartlist_t *mapping_lines = smartlist_new();
      SMARTLIST_FOREACH_BEGIN(tokens, const directory_token_t *, t) {
        if (t->tp == K_OPT && t->n_args >= 1) {
          smartlist_add(mapping_lines, t->args[0]);
        }
      } SMARTLIST_FOREACH_END(t);

      smartlist_sort_strings(mapping_lines);
      char *joined = smartlist_join_strings(mapping_lines, "\n", 0, NULL);
      char mapping_digest[DIGEST256_LEN];
      crypto_digest256(mapping_digest, joined, strlen(joined), DIGEST_SHA256);
      tor_free(joined);
      smartlist_free(mapping_lines);

      /* Hex-encode our computed digest and compare. */
      char computed_hex[HEX_DIGEST256_LEN + 1];
      base16_encode(computed_hex, sizeof(computed_hex),
                    mapping_digest, DIGEST256_LEN);
      if (strcasecmp(computed_hex, tok->args[1]) != 0) {
        log_warn(LD_DIR, "anyone_hosts: mapping content digest mismatch. "
                 "File may have been modified after signing.");
        /* Signature over the full document already passed, so this indicates
         * the digest field itself was wrong at signing time, or the mappings
         * were reordered. Not fatal. */
      }
    }
  }

  result = ANYONE_HOSTS_SIG_VALID;

 done:
  if (tokens) {
    SMARTLIST_FOREACH(tokens, directory_token_t *, t, token_clear(t));
    smartlist_free(tokens);
  }
  if (area)
    memarea_drop_all(area);
  return result;
}
