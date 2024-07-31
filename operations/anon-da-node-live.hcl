#TODO: use templating to avoid copypaste

job "ator-dir-auth-live" {
  datacenters = ["ator-fin"]
  type = "service"
  namespace = "ator-network"

  group "dir-auth-live-group" {
    count = 7

    spread {
      attribute = "${node.unique.id}"
      weight    = 100
      target "067a42a8-d8fe-8b19-5851-43079e0eabb4" {
        percent = 14
      }
      target "16be0723-edc1-83c4-6c02-193d96ec308a" {
        percent = 14
      }
      target "e6e0baed-8402-fd5c-7a15-8dd49e7b60d9" {
        percent = 14
      }
      target "5ace4a92-63c4-ac72-3ed1-e4485fa0d4a4" {
        percent = 14
      }
      target "eb42c498-e7a8-415f-14e9-31e9e71e5707" {
        percent = 14
      }
      target "4aa61f61-893a-baf4-541b-870e99ac4839" {
        percent = 15
      }
      target "c2adc610-6316-cd9d-c678-cda4b0080b52" {
        percent = 15
      }
    }

    network  {
      port "orport" {
        static = 9201
      }
      port "dirport" {
        static = 9230
      }

    }

    volume "dir-auth-live" {
      type      = "host"
      read_only = false
      source    = "dir-auth-live"
    }

    volume "sbws-live" {
      type      = "host"
      read_only = false
      source    = "sbws-live"
    }

    task "dir-auth-live-task" {
      driver = "docker"

      volume_mount {
        volume      = "dir-auth-live"
        destination = "/var/lib/anon/"
        read_only   = false
      }

      volume_mount {
        volume      = "sbws-live"
        destination = "/var/lib/sbws/"
        read_only   = false
      }

      config {
        image = "ghcr.io/ator-development/ator-protocol-live:PLACEIMAGETAGHERE"
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
        cpu = 2560
        memory = 2560
      }

      template {
        change_mode = "noop"
        data = <<EOH
           {{ key (env `node.unique.id` | printf `ator-network/live/dir-auth-%s/authority_certificate`) }}
        EOH
        destination = "secrets/anon/keys/authority_certificate"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (env `node.unique.id` | printf `kv/ator-network/live/dir-auth-%s`) }}{{ .Data.data.authority_identity_key}}{{end}}"
        destination = "secrets/anon/keys/authority_identity_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/ator-network/live/dir-auth-%s`) }}{{.Data.data.authority_signing_key}}{{end}}"
        destination = "secrets/anon/keys/authority_signing_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/ator-network/live/dir-auth-%s`) }}{{ base64Decode .Data.data.ed25519_master_id_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_master_id_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/ator-network/live/dir-auth-%s`) }}{{ base64Decode .Data.data.ed25519_signing_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_signing_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/ator-network/live/dir-auth-%s`) }}{{ base64Decode .Data.data.secret_id_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_id_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/ator-network/live/dir-auth-%s`) }}{{ base64Decode .Data.data.secret_onion_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/ator-network/live/dir-auth-%s`) }}{{ base64Decode .Data.data.secret_onion_key_ntor_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key_ntor"
      }

      template {
        change_mode = "noop"
        data = <<EOH
# Run Tor as a regular user (do not change this)
User anond
DataDirectory /var/lib/anon

AgreeToTerms 1

AuthoritativeDirectory 1
V3AuthoritativeDirectory 1

# Server's public IP Address (usually automatic)
Address {{ key (env "node.unique.id" | printf "ator-network/live/dir-auth-%s/public_ipv4") }}

# Port to advertise for incoming Tor connections.
ORPort 9201                  # common ports are 9001, 443
#ORPort 1.1.1.1:9001

# Mirror directory information for others (optional, not used on bridge)
DirPort 9230                 # common ports are 9030, 80

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
Nickname {{ key (env "node.unique.id" | printf "ator-network/live/dir-auth-%s/nickname") }}
ContactInfo atorv4@example.org

V3BandwidthsFile /var/lib/sbws/v3bw/latest.v3bw
        EOH
        destination = "local/anonrc"
      }

      service {
        name = "dir-auth-live"
        port = "dirport"
        tags     = ["logging"]
        check {
          name     = "dir auth alive"
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
