job "dir-auth-stage" {
  datacenters = ["ator-fin"]
  type = "service"
  namespace = "ator-network"

  meta {
    anonrc_template = <<EOF
# Run Tor as a regular user (do not change this)
User anond
DataDirectory /var/lib/anon

AgreeToTerms 1

AuthoritativeDirectory 1
V3AuthoritativeDirectory 1

# Run Tor only as a server (no local applications)
SocksPort 0
ControlSocket 0

# Run as a relay only (change policy to enable exit node)
ExitPolicy reject *:*        # no exits allowed
ExitPolicy reject6 *:*
ExitRelay 0
IPv6Exit 0

AuthDirMaxServersPerAddr 8

ConsensusParams "CircuitPriorityHalflifeMsec=30000 DoSCircuitCreationBurst=60 DoSCircuitCreationEnabled=1 DoSCircuitCreationMinConnections=2 DoSCircuitCreationRate=2 DoSConnectionEnabled=1 DoSConnectionMaxConcurrentCount=50 DoSRefuseSingleHopClientRendezvous=1 ExtendByEd25519ID=1 KISTSchedRunInterval=3 NumNTorsPerTAP=100 UseOptimisticData=1 bwauthpid=1 bwscanner_cc=1 cbttestfreq=10 cc_alg=2 cc_cwnd_full_gap=4 cc_cwnd_full_minpct=25 cc_cwnd_inc=1 cc_cwnd_inc_rate=31 cc_cwnd_min=124 cc_sscap_exit=600 cc_sscap_onion=475 cc_vegas_alpha_exit=186 cc_vegas_beta_onion=372 cc_vegas_delta_exit=310 cc_vegas_delta_onion=434 cc_vegas_gamma_onion=248 cfx_low_exit_threshold=5000 circ_max_cell_queue_size=1250 circ_max_cell_queue_size_out=1000 dos_num_circ_max_outq=5 guard-n-primary-dir-guards-to-use=2"

# Set limits
#AccountingMax 999 GB
#RelayBandwidthRate 512 KB   # Throttle traffic to
#RelayBandwidthBurst 1024 KB # But allow bursts up to
#MaxMemInQueues 512 MB       # Limit Memory usage to

## If no Nickname or ContactInfo is set, docker-entrypoint will use
## the environment variables to add Nickname/ContactInfo below
ContactInfo atorv4@example.org

V3BandwidthsFile /var/lib/sbws/v3bw/latest.v3bw
EOF
  }

  spread {
    attribute = "${node.unique.id}"
    weight    = 100
    target "f3f664d6-7d65-be58-4a2c-4c66e20f1a9f" {
      percent = 14
    }
    target "232ea736-591c-4753-9dcc-3e815c4326af" {
      percent = 43
    }
    target "4ca2fc3c-8960-6ae7-d931-c0d6030d506b" {
      percent = 43
    }
  }

  group "dir-auth-stage" {
    count = 3

    constraint {
      attribute = "${node.unique.id}"
      operator  = "set_contains_any"
      value     = "4ca2fc3c-8960-6ae7-d931-c0d6030d506b,232ea736-591c-4753-9dcc-3e815c4326af,f3f664d6-7d65-be58-4a2c-4c66e20f1a9f"
    }

    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }
    
    network {
      mode = "bridge"
      port "orport" {
        static = 9101
      }
      port "dirport" {
        static = 9130
      }
    }

    volume "dir-auth-stage" {
      type      = "host"
      read_only = false
      source    = "dir-auth-stage"
    }

    volume "sbws-stage" {
      type      = "host"
      read_only = false
      source    = "sbws-stage"
    }

    task "dir-auth-stage-task" {
      driver = "docker"

      volume_mount {
        volume      = "dir-auth-stage"
        destination = "/var/lib/anon/"
        read_only   = false
      }

      volume_mount {
        volume      = "sbws-stage"
        destination = "/var/lib/sbws/"
        read_only   = false
      }

      config {
        image = "ghcr.io/anyone-protocol/ator-protocol-stage:PLACEIMAGETAGHERE"
        ports = ["orport", "dirport"]
        volumes = [
          "local/anonrc:/etc/anon/anonrc",
          "secrets/anon/keys:/var/lib/anon/keys"
        ]
      }

      vault {
        policies = ["ator-network-read"]
      }

      resources {
        cpu    = 2560
        memory = 2560
      }

      template {
        change_mode = "noop"
        data = <<EOH
           {{ key (printf `ator-network/stage/dir-auth-%s-%s/authority_certificate` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}
        EOH
        destination = "secrets/anon/keys/authority_certificate"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ .Data.data.authority_identity_key}}{{end}}"
        destination = "secrets/anon/keys/authority_identity_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{.Data.data.authority_signing_key}}{{end}}"
        destination = "secrets/anon/keys/authority_signing_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.ed25519_master_id_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_master_id_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.ed25519_signing_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_signing_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.secret_id_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_id_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.secret_onion_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.secret_onion_key_ntor_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key_ntor"
      }

      template {
        change_mode = "noop"
        data = <<EOH
{{ env "NOMAD_META_anonrc_template" }}

# Server's public IP Address (usually automatic)
Address {{ key (printf "ator-network/stage/dir-auth-%s-%s/public_ipv4" (env "node.unique.id") (env "NOMAD_PORT_orport")) }}

# Port to advertise for incoming Tor connections.
ORPort {{ env "NOMAD_PORT_orport" }}

# Mirror directory information for others (optional, not used on bridge)
DirPort {{ env "NOMAD_PORT_dirport" }}

Nickname {{ key (printf "ator-network/stage/dir-auth-%s-%s/nickname" (env "node.unique.id") (env "NOMAD_PORT_orport")) }}
        EOH
        destination = "local/anonrc"
      }

      service {
        name = "dir-auth-stage-1"
        port = "dirport"
        tags = ["logging"]
        check {
          name     = "dir auth stage alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "10s"
          check_restart {
            limit = 10
            grace = "30s"
          }
        }
      }
    }
  }

  group "dir-auth-stage-group-2" {
    count = 2

    constraint {
      attribute = "${node.unique.id}"
      operator  = "set_contains_any"
      value     = "232ea736-591c-4753-9dcc-3e815c4326af,4ca2fc3c-8960-6ae7-d931-c0d6030d506b"
    }

    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    network {
      mode = "bridge"
      port "orport" {
        static = 9102
      }
      port "dirport" {
        static = 9131
      }
    }

    volume "dir-auth-stage-2" {
      type      = "host"
      read_only = false
      source    = "dir-auth-stage-2"
    }

    volume "sbws-stage-2" {
      type      = "host"
      read_only = false
      source    = "sbws-stage-2"
    }

    task "dir-auth-stage-task" {
      driver = "docker"

      volume_mount {
        volume      = "dir-auth-stage-2"
        destination = "/var/lib/anon/"
        read_only   = false
      }

      volume_mount {
        volume      = "sbws-stage-2"
        destination = "/var/lib/sbws/"
        read_only   = false
      }

      config {
        image = "ghcr.io/anyone-protocol/ator-protocol-stage:PLACEIMAGETAGHERE"
        ports = ["orport", "dirport"]
        volumes = [
          "local/anonrc:/etc/anon/anonrc",
          "secrets/anon/keys:/var/lib/anon/keys"
        ]
      }

      vault {
        policies = ["ator-network-read"]
      }

      resources {
        cpu    = 2560
        memory = 2560
      }

      template {
        change_mode = "noop"
        data = <<EOH
           {{ key (printf `ator-network/stage/dir-auth-%s-%s/authority_certificate` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}
        EOH
        destination = "secrets/anon/keys/authority_certificate"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ .Data.data.authority_identity_key}}{{end}}"
        destination = "secrets/anon/keys/authority_identity_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{.Data.data.authority_signing_key}}{{end}}"
        destination = "secrets/anon/keys/authority_signing_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.ed25519_master_id_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_master_id_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.ed25519_signing_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_signing_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.secret_id_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_id_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.secret_onion_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.secret_onion_key_ntor_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key_ntor"
      }

      template {
        change_mode = "noop"
        data = <<EOH
{{ env "NOMAD_META_anonrc_template" }}

# Server's public IP Address (usually automatic)
Address {{ key (printf "ator-network/stage/dir-auth-%s-%s/public_ipv4" (env "node.unique.id") (env "NOMAD_PORT_orport")) }}

# Port to advertise for incoming Tor connections.
ORPort {{ env "NOMAD_PORT_orport" }}

# Mirror directory information for others (optional, not used on bridge)
DirPort {{ env "NOMAD_PORT_dirport" }}

Nickname {{ key (printf "ator-network/stage/dir-auth-%s-%s/nickname" (env "node.unique.id") (env "NOMAD_PORT_orport")) }}
        EOH
        destination = "local/anonrc"
      }

      service {
        name = "dir-auth-stage-2"
        port = "dirport"
        tags = ["logging"]
        check {
          name     = "dir auth stage alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "10s"
          check_restart {
            limit = 10
            grace = "30s"
          }
        }
      }
    }
  }

  group "dir-auth-stage-group-3" {
    count = 2

    constraint {
      attribute = "${node.unique.id}"
      operator  = "set_contains_any"
      value     = "232ea736-591c-4753-9dcc-3e815c4326af,4ca2fc3c-8960-6ae7-d931-c0d6030d506b"
    }

    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    network {
      mode = "bridge"
      port "orport" {
        static = 9103
      } 
      port "dirport" {
        static = 9132
      }
    }

    volume "dir-auth-stage-3" {
      type      = "host"
      read_only = false
      source    = "dir-auth-stage-3"
    }

    volume "sbws-stage-3" {
      type      = "host"
      read_only = false
      source    = "sbws-stage-3"
    }

    task "dir-auth-stage-task" {
        driver = "docker"
     volume_mount {
        volume      = "dir-auth-stage-3"
        destination = "/var/lib/anon/"
        read_only   = false
      }

      volume_mount {
        volume      = "sbws-stage-3"
        destination = "/var/lib/sbws/"
        read_only   = false
      }

      config {
        image = "ghcr.io/anyone-protocol/ator-protocol-stage:PLACEIMAGETAGHERE"
        ports = ["orport", "dirport"]
        volumes = [
          "local/anonrc:/etc/anon/anonrc",
          "secrets/anon/keys:/var/lib/anon/keys"
        ]
      }

      vault {
        policies = ["ator-network-read"]
      }

      resources {
        cpu    = 2560
        memory = 2560
      }

      template {
        change_mode = "noop"
        data = <<EOH
           {{ key (printf `ator-network/stage/dir-auth-%s-%s/authority_certificate` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}
        EOH
        destination = "secrets/anon/keys/authority_certificate"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ .Data.data.authority_identity_key}}{{end}}"
        destination = "secrets/anon/keys/authority_identity_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{.Data.data.authority_signing_key}}{{end}}"
        destination = "secrets/anon/keys/authority_signing_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.ed25519_master_id_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_master_id_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.ed25519_signing_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_signing_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.secret_id_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_id_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.secret_onion_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (printf `kv/ator-network/stage/dir-auth-%s-%s` (env `node.unique.id`) (env `NOMAD_PORT_orport`)) }}{{ base64Decode .Data.data.secret_onion_key_ntor_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key_ntor"
      }

      template {
        change_mode = "noop"
        data = <<EOH
{{ env "NOMAD_META_anonrc_template" }}

# Server's public IP Address (usually automatic)
Address {{ key (printf "ator-network/stage/dir-auth-%s-%s/public_ipv4" (env "node.unique.id") (env "NOMAD_PORT_orport")) }}

# Port to advertise for incoming Tor connections.
ORPort {{ env "NOMAD_PORT_orport" }}

# Mirror directory information for others (optional, not used on bridge)
DirPort {{ env "NOMAD_PORT_dirport" }}

Nickname {{ key (printf "ator-network/stage/dir-auth-%s-%s/nickname" (env "node.unique.id") (env "NOMAD_PORT_orport")) }}
        EOH
        destination = "local/anonrc"
      }

      service {
        name = "dir-auth-stage-3"
        port = "dirport"
        tags = ["logging"]
        check {
          name     = "dir auth stage alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "10s"
          check_restart {
            limit = 10
            grace = "30s"
          }
        }
      }
    }
  }
}