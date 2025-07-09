#TODO: use templating to avoid copypaste

job "anon-da-node-live" {
  datacenters = ["ator-fin"]
  type = "service"
  namespace = "live-network"

  update {
    max_parallel      = 1
    healthy_deadline  = "15m"
    progress_deadline = "20m"
  }

  group "dir-auth-live-group" {
    count = 7

    spread {
      attribute = "${node.unique.id}"
      weight    = 100
      target "ee5aa04f-1ec2-832e-e706-4b3d996429f4" {
        percent = 14
      }
      target "c5c9db77-6779-bcd7-8aa5-559f03254e7f" {
        percent = 14
      }
      target "e8c69a64-abee-23b0-8a27-04d5de1c0125" {
        percent = 14
      }
      target "fd1258af-0be7-7946-bccf-565243a753db" {
        percent = 14
      }
      target "e5e906fa-af5a-bff1-e0c5-f8e12bb385f7" {
        percent = 14
      }
      target "ababa2ce-7129-d4b9-f9c4-b0e6f9d80f7f" {
        percent = 15
      }
      target "63fdf9a5-4ea8-4c12-5f6b-b59479d95d12" {
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
        image = "ghcr.io/anyone-protocol/ator-protocol:PLACEIMAGETAGHERE"
        image_pull_timeout = "15m"
        ports = ["orport", "dirport"]
        volumes = [
          "local/anonrc:/etc/anon/anonrc",
          "secrets/anon/keys:/var/lib/anon/keys"
        ]
      }

      vault {
        role = "any1-nomad-workloads-controller"
      }

      identity {
        name = "vault_default"
        aud  = ["any1-infra"]
        ttl  = "1h"
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
        data = "{{ with secret (env `node.unique.id` | printf `kv/live-network/anon-da-node-live/dir-auth-%s`) }}{{ .Data.data.authority_identity_key}}{{end}}"
        destination = "secrets/anon/keys/authority_identity_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/live-network/anon-da-node-live/dir-auth-%s`) }}{{.Data.data.authority_signing_key}}{{end}}"
        destination = "secrets/anon/keys/authority_signing_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/live-network/anon-da-node-live/dir-auth-%s`) }}{{ base64Decode .Data.data.ed25519_master_id_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_master_id_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/live-network/anon-da-node-live/dir-auth-%s`) }}{{ base64Decode .Data.data.ed25519_signing_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_signing_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/live-network/anon-da-node-live/dir-auth-%s`) }}{{ base64Decode .Data.data.secret_id_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_id_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/live-network/anon-da-node-live/dir-auth-%s`) }}{{ base64Decode .Data.data.secret_onion_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `node.unique.id` | printf `kv/live-network/anon-da-node-live/dir-auth-%s`) }}{{ base64Decode .Data.data.secret_onion_key_ntor_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key_ntor"
      }

      template {
        change_mode = "noop"
        data = <<-EOH
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
        check {
          name = "dir auth live consensus check"
          type = "http"
          port = "dirport"
          path = "/tor/status-vote/current/consensus"
          interval = "10s"
          timeout = "10s"
        }
      }
    }
  }
}
