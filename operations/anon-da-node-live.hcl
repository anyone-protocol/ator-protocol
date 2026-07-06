variable "anyone_client_tag" {
  type        = string
  description = "The anyone client container image tag to deploy for the directory authority live relay task"
  default     = "4be828669dd2dacffdae8abe650f56ab0de85643" // v0.4.10.2
}

variable "curl_image_tag" {
  type        = string
  description = "The curl container image tag to deploy for the bandwidth puller task"
  default     = "8.20.0"
}

job "anon-da-node-live" {
  datacenters = ["ator-fin"]
  type = "service"
  namespace = "live-network"

  update {
    max_parallel      = 1
    healthy_deadline  = "10m"
    progress_deadline = "60m"
  }

  constraint {
    attribute = "${meta.pool}"
    value = "live-network-authorities"
  }
  constraint {
    attribute = "${meta.role}"
    value = "directory-authority"
  }
  constraint {
    distinct_hosts = true
  }

  group "dir-auth-live-group" {
    # NB: 7 directory authorities, one per host. Each pulls its v3bw from a specific
    # bandwidth authority via that BA's per-host Consul service (sbws-bandwidth-<ba-hostname>).
    # Mapping (DA -> BA): fal->lim, nur->lim, hel->bgr, ash-1->chi, ash-2->jnb, hil-1->sea, hil-2->sin
    # nur->lim is temporary; nur should map to fra once fra sbws graduates from bootstrapping.
    count = 7

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

    task "dir-auth-live-task" {
      driver = "docker"

      volume_mount {
        volume      = "dir-auth-live"
        destination = "/var/lib/anon/"
        read_only   = false
      }

      config {
        image = "ghcr.io/anyone-protocol/ator-protocol-amd64:${var.anyone_client_tag}"
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

      consul {}

      resources {
        cpu = 1024
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

        V3BandwidthsFile /alloc/sbws/latest.v3bw
        EOH
        destination = "local/anonrc"
      }

      service {
        name = "dir-auth-live"
        port = "dirport"
        tags     = ["logging"]
        check {
          name     = "dir auth live alive"
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

    task "sbws-bandwidth-puller" {
      lifecycle {
        hook = "prestart"
        sidecar = true
      }

      driver = "docker"

      config {
        image   = "curlimages/curl:${var.curl_image_tag}"
        command = "/bin/sh"
        args    = ["-c", "/local/puller.sh"]
      }

      consul {}

      env {
        CADENCE = 300
      }

      template {
        data = <<-EOF
        {{- $ba := "" -}}
        {{- if eq (env "attr.unique.hostname") "any1-live-fal-net-auth-1" -}}{{- $ba = "any1-live-lim-net-auth-1" -}}
        {{- else if eq (env "attr.unique.hostname") "any1-live-nur-net-auth-1" -}}{{- $ba = "any1-live-lim-net-auth-1" -}}
        {{- else if eq (env "attr.unique.hostname") "any1-live-hel-net-auth-1" -}}{{- $ba = "any1-live-bgr-net-auth-1" -}}
        {{- else if eq (env "attr.unique.hostname") "any1-live-ash-net-auth-1" -}}{{- $ba = "any1-live-chi-net-auth-1" -}}
        {{- else if eq (env "attr.unique.hostname") "any1-live-ash-net-auth-2" -}}{{- $ba = "any1-live-jnb-net-auth-1" -}}
        {{- else if eq (env "attr.unique.hostname") "any1-live-hil-net-auth-1" -}}{{- $ba = "any1-live-sea-net-auth-1" -}}
        {{- else if eq (env "attr.unique.hostname") "any1-live-hil-net-auth-2" -}}{{- $ba = "any1-live-sin-net-auth-1" -}}
        {{- end -}}
        V3BW_URL="{{- range service (printf "sbws-bandwidth-%s" $ba) }}http://{{ .Address }}:{{ .Port }}/latest.v3bw{{- end }}"
        EOF
        destination = "secrets/env"
        env         = true
      }

      template {
        data = <<-EOF
        #!/bin/sh

        # Ensure files we create are world-readable: the relay task runs as
        # 'anond' (different UID than curl_user inside this container), and
        # reads the file across the shared /alloc bind-mount.
        umask 022

        LOCAL_FILE="/alloc/sbws/latest.v3bw"
        TMP_FILE="/alloc/sbws/latest.v3bw.new"

        mkdir -p /alloc/sbws
        chmod 0755 /alloc/sbws

        echo "Starting sbws v3bw bandwidth file puller with URL: $V3BW_URL"

        while true; do
          # -z   : only download if server file is newer than local file (sends If-Modified-Since)
          # -R   : preserve server's Last-Modified as the local file's mtime (so -z keeps working)
          # -f   : fail on HTTP >= 400 (note: 304 is NOT an error, curl exits 0)
          # -s   : silent
          # -o   : write body to temp file (curl creates this file even on 304, so we must
          #        check the status code rather than file existence)
          # -w   : print the HTTP status code so we can branch on 200 vs 304
          rm -f "$TMP_FILE"
          HTTP_CODE=$(curl -f -s -R -z "$LOCAL_FILE" \
            -o "$TMP_FILE" \
            -w '%%{http_code}' \
            "$V3BW_URL") || HTTP_CODE="000"

          case "$HTTP_CODE" in
            200)
              # File changed → atomic replace (-R already set the mtime on TMP_FILE)
              chmod 0644 "$TMP_FILE"
              mv "$TMP_FILE" "$LOCAL_FILE"
              echo "$(date '+%Y-%m-%d %H:%M:%S') - latest.v3bw UPDATED (200)"
              ;;
            304)
              rm -f "$TMP_FILE"
              echo "$(date '+%Y-%m-%d %H:%M:%S') - not modified (304)"
              ;;
            *)
              rm -f "$TMP_FILE"
              echo "$(date '+%Y-%m-%d %H:%M:%S') - pull failed (HTTP $HTTP_CODE)"
              ;;
          esac

          sleep $CADENCE
        done
        EOF
        destination = "local/puller.sh"
        perms       = "0777"
      }

      resources {
        cpu    = 128
        memory = 128
      }
    }
  }
}
