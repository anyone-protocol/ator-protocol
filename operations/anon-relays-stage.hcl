locals {
  instances_count = 4
  nicnname_prefix = "AnonFamilyRelay"
	nicknames = [for i in range(0, local.instances_count) : "${local.nicnname_prefix}${i}"]
	nicknames_string = join(",", local.nicknames)
}


job "relays-family-stage" {
  datacenters = ["ator-fin"]
  type = "service"
  namespace = "ator-network"

  update {
    max_parallel      = 1
    healthy_deadline  = "15m"
    progress_deadline = "20m"
  }

  group "relay-live-group" {
    count = local.instances_count

    spread {
      attribute = "${node.unique.id}"
      weight    = 100
      target "f3f664d6-7d65-be58-4a2c-4c66e20f1a9f" {
        percent = 33
      }
      target "232ea736-591c-4753-9dcc-3e815c4326af" {
        percent = 33
      }
      target "4ca2fc3c-8960-6ae7-d931-c0d6030d506b" {
        percent = 34
      }
  	}

    constraint {
        attribute = "${node.unique.id}"
        operator  = "set_contains_any"
        value     = "4ca2fc3c-8960-6ae7-d931-c0d6030d506b,232ea736-591c-4753-9dcc-3e815c4326af,f3f664d6-7d65-be58-4a2c-4c66e20f1a9f"
    }

    network  {
      port "orport" {
        static = 0
      }
    }

    task "relay-live-task" {
      driver = "docker"

      config {
        # todo - use latest commit tag - https://github.com/anyone-protocol/jira-confluence/issues/224
        image = "ghcr.io/anyone-protocol/ator-protocol-stage:4b413cc6c0c82e4baefeb3545efe5bc416913700"
        image_pull_timeout = "15m"
        ports = ["orport"]
        volumes = [
          "local/anonrc:/etc/anon/anonrc",
          "secrets/anon/keys:/var/lib/anon/keys"
        ]
      }

      env {
				NICKNAMES_STRING = local.nicknames_string
        NICKNAME_PREFIX = local.nicnname_prefix
			}

      vault {
        policies = ["ator-network-read"]
      }

      resources {
        cpu = 256
        memory = 2048
      }

   
      template {
        change_mode = "noop"
        data = <<EOH
           {{ key (env `NOMAD_ALLOC_INDEX` | printf `ator-network/stage/relay-family-%s/authority_certificate`) }}
        EOH
        destination = "secrets/anon/keys/authority_certificate"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{ .Data.data.authority_identity_key}}{{end}}"
        destination = "secrets/anon/keys/authority_identity_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{.Data.data.authority_signing_key}}{{end}}"
        destination = "secrets/anon/keys/authority_signing_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{ base64Decode .Data.data.ed25519_master_id_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_master_id_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{ base64Decode .Data.data.ed25519_signing_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_signing_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{ base64Decode .Data.data.secret_id_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_id_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{ base64Decode .Data.data.secret_onion_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{ base64Decode .Data.data.secret_onion_key_ntor_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key_ntor"
      }

      template {
        change_mode = "noop"
        data = <<EOH
User anond
DataDirectory /var/lib/anon

AgreeToTerms 1

ORPort {{ env `NOMAD_PORT_orport` }}

Nickname {{ env `NICKNAME_PREFIX` }}{{ env `NOMAD_ALLOC_INDEX` }}
ContactInfo anon@example.org
MyFamily 47B1B159AFD0597DB5BA7B9F743DC57D47BE2265,AF2E54656194C619B19EAB80887F37A83E6C3E43,954BBF10940BCD4B5797558145B55824C0314EB3,639BBF0705242A244EBD2DA5418AE7B7169AF1CA
        EOH
        destination = "local/anonrc"
      }
    }
  }
}
