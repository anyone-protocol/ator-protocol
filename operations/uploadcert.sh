#arguments tor-data-folder node-id ip nickname

consul kv put ator-network/stage/dir-aut-$2/authority_certificate $(cat keys/authority_certificate)
consul kv put ator-network/stage/dir-aut-$2/ed25519_master_id_public_key_base64 $(base64 keys/ed25519_master_id_public_key)
consul kv put ator-network/stage/dir-aut-$2/ed25519_signing_cert_base64 $(base64 keys/ed25519_signing_cert)
consul kv put ator-network/stage/dir-aut-$2/fingerprint $(cat fingerprint)
consul kv put ator-network/stage/dir-aut-$2/fingerprint-ed25519 $(cat fingerprint-ed25519)
consul kv put ator-network/stage/dir-aut-$2/nickname $4
consul kv put ator-network/stage/dir-aut-$2/public_ipv4 $3

vault kv put kv/ator-network/stage/dir-auth-$2
            authority_identity_key=$(cat keys/authority_identity_key) 
            authority_signing_key=$(cat keys/authority_signing_key) 
            ed25519_master_id_secret_key_base64=$(base64 keys/ed25519_master_id_secret_key) 
            ed25519_signing_secret_key_base64=$(base64 keys/ed25519_signing_secret_key) 
            secret_id_key_base64=$(base64 keys/secret_id_key)
            secret_onion_key_base64=$(base64 keys/secret_onion_key)
            secret_onion_key_ntor_base64=$(base64 keys/secret_onion_key_ntor)