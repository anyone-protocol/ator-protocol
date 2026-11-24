# Anyone Protocol Client Operations

## Runtime Services requireing relay sidecar

### Network
- Directory Authorities ([live job spec](./anon-da-node-live.hcl))
- Bandwidth Authorities ([sbws](../../sbws))

### Hidden Services
- Anyone DNS ([anyone-dns](../../anyone-dns/))
- Anon Check ([anon-check](../../anon-check/))
- Anon Hidden Website ([infra-services](../../infra-services/))

## Renewing live Directory Authority certificates

The directory authorities use the v3 dir-auth key scheme: a long-term **identity
key** (offline-ish, the thing that defines the DA fingerprint / v3ident) that
certifies a shorter-lived **signing key** via an **authority certificate**. The
certificate expires (default 12 months). When it does, votes/consensus from that
DA stop being accepted until it's renewed.

Check current expiry with [check-da-certs.sh](./check-da-certs.sh):

```sh
bash operations/check-da-certs.sh   # look at the dir-key-expires lines
```

### The one rule

**Reuse the existing identity key. Do NOT generate a new one.**

Renewal = new **signing key** + new **certificate**, signed by the *same*
identity key. The DA fingerprints stay the same, so no clients or relays need
reconfiguring.

> ⚠️ The `gencert.sh` / `run-gen-upload-cert.sh` scripts in this folder run
> `anon-gencert --create-identity-key`, which mints a **brand new identity** and
> a fresh full keyset. That is for *provisioning a new DA*, not renewal. Using it
> to "renew" would change the DA fingerprints and break the whole network. Don't.

### Where the pieces live

For each DA, keyed off its Nomad `node.unique.id` (see
[anon-da-node-live.hcl](./anon-da-node-live.hcl)):

| What | Store | Path |
| --- | --- | --- |
| `authority_certificate` | Consul KV | `ator-network/live/dir-auth-<node-id>/authority_certificate` |
| `authority_signing_key` | Vault (kv) | `kv/live-network/anon-da-node-live/dir-auth-<node-id>` field `authority_signing_key` |
| `authority_identity_key` | Vault (kv) | same secret, field `authority_identity_key` — **read-only here, never overwrite** |

Current live node IDs (the stale ones in `run-gen-upload-cert.sh` are from an
older deployment — do not use those). Node IDs change if a host is rebuilt, so
re-confirm with `consul kv get -keys ator-network/live/` before a renewal.

### Procedure (per DA)

Run from an operator box that has `docker`, and `vault` / `consul` / `nomad`
configured (`VAULT_ADDR`+`VAULT_TOKEN`, `CONSUL_HTTP_ADDR`+`CONSUL_HTTP_TOKEN`+
`CONSUL_CACERT`, `NOMAD_ADDR`+`NOMAD_TOKEN`).

Set the DA you're renewing, and use the same client image tag the live job runs
(`var.anyone_client_tag` in the hcl):

```sh
NODE_ID=<node-unique-id>
IMAGE=ghcr.io/anyone-protocol/ator-protocol-amd64:4be828669dd2dacffdae8abe650f56ab0de85643  # v0.4.10.2
mkdir -p renew/$NODE_ID/keys && cd renew/$NODE_ID
```

1. **Pull the existing identity key** out of Vault (this is the only thing we
   reuse):

   ```sh
   vault kv get -mount=kv -field=authority_identity_key \
     live-network/anon-da-node-live/dir-auth-$NODE_ID > keys/authority_identity_key
   ```

   Check whether it's passphrase-protected — if this prints a line, it is, and
   you'll need that passphrase in the next step:

   ```sh
   grep ENCRYPTED keys/authority_identity_key
   ```

2. **Generate a new signing key + certificate**, reusing the identity key.
   `anon-gencert` reads `./authority_identity_key` and writes
   `./authority_signing_key` + `./authority_certificate`. Note: **no**
   `--create-identity-key` flag. `-m 12` = 12-month validity.

   ```sh
   # unencrypted identity key:
   docker run -i --rm -w /keys -v "$PWD/keys:/keys" $IMAGE anon-gencert -m 12

   # OR, if the identity key is passphrase-protected, feed the passphrase on stdin:
   printf '%s' 'THE-PASSPHRASE' | \
     docker run -i --rm -w /keys -v "$PWD/keys:/keys" $IMAGE anon-gencert -m 12 --passphrase-fd 0

   sudo chown -R "$USER:$USER" keys   # anon-gencert writes as root in the container
   ```

   Sanity-check the new validity window:

   ```sh
   grep -E 'dir-key-(published|expires)' keys/authority_certificate
   ```

3. **Publish the new certificate** to Consul:

   ```sh
   consul kv put ator-network/live/dir-auth-$NODE_ID/authority_certificate \
     "$(cat keys/authority_certificate)"
   ```

4. **Patch the new signing key** into Vault. Use `patch`, not `put`, so the
   other fields in that secret (identity key, ed25519/onion keys) are left alone:

   ```sh
   vault kv patch -mount=kv live-network/anon-da-node-live/dir-auth-$NODE_ID \
     authority_signing_key="$(cat keys/authority_signing_key)"
   ```

Repeat 1–4 for each DA. The identity key file and all other relay keys are never
modified.

### Roll the allocations

The job templates use `change_mode = "noop"`, so updating Consul/Vault does **not**
restart anon on its own. Restart the allocs so they re-render the new keys —
**one at a time**, since consensus needs a majority (4 of 7) of DAs up:

```sh
nomad job restart -group dir-auth-live-group anon-da-node-live
# or per alloc:  nomad alloc restart <alloc-id>
```

Verify after each:

```sh
bash operations/check-da-certs.sh   # expect fresh dir-key-expires ~12 months out
```

### Don't get caught expired again

Renew ~1 month **before** expiry so the new cert propagates while the old one is
still valid (no overlap window once it's already expired). Worth wiring
`check-da-certs.sh` into a cron/alert that warns ~30 days out.
