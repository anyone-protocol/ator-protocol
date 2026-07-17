locals {
  # reprepro config shared by the main reprepro task and the prestart
  # clearvanished task, so both always see the same set of distributions.
  reprepro_distributions = <<-EOH
    Origin: Anon
    Label: Anon
    Codename: anon-live-bookworm
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Bookworm Live
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-live-bullseye
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Bullseye Live
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-live-trixie
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Trixie Live
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-live-noble
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Noble Live
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-live-jammy
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Jammy Live
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-live-focal
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Focal Live
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-live-questing
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Questing Live
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-live-resolute
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Resolute Live
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-beta-bookworm
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Bookworm Beta
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-beta-bullseye
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Bullseye Beta
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-beta-trixie
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Trixie Beta
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-beta-noble
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Noble Beta
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-beta-jammy
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Jammy Beta
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-beta-focal
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Focal Beta
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-beta-questing
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Questing Beta
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-beta-resolute
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Resolute Beta
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-stage-bookworm
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Bookworm Stage
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-stage-bullseye
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Bullseye Stage
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-stage-trixie
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Trixie Stage
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-stage-noble
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Noble Stage
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-stage-jammy
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Jammy Stage
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-stage-focal
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Focal Stage
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-stage-questing
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Questing Stage
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-stage-resolute
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Resolute Stage
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-dev-bookworm
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Bookworm Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-dev-bullseye
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Bullseye Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-dev-trixie
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Trixie Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-dev-noble
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Noble Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-dev-jammy
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Jammy Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-dev-focal
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Focal Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-dev-questing
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Questing Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-dev-resolute
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Resolute Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-unstable-dev-bookworm
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Bookworm Unstable Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-unstable-dev-bullseye
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Bullseye Unstable Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-unstable-dev-trixie
    Architectures: amd64 arm64 source
    Components: main
    Description: Anon Debian Trixie Unstable Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-unstable-dev-noble
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Noble Unstable Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-unstable-dev-jammy
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Jammy Unstable Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-unstable-dev-focal
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Focal Unstable Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-unstable-dev-questing
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Questing Unstable Dev
    SignWith: YES

    Origin: Anon
    Label: Anon
    Codename: anon-unstable-dev-resolute
    Architectures: amd64 arm64 source
    Components: main
    DDebComponents: main
    Description: Anon Ubuntu Resolute Unstable Dev
    SignWith: YES
  EOH

  reprepro_incoming = <<-EOH
    Name: incoming
    IncomingDir: /data/debian/incoming
    TempDir: /tmp
    Allow: anon-live-bookworm anon-live-bullseye anon-live-trixie anon-live-noble anon-live-jammy anon-live-focal anon-live-questing anon-live-resolute anon-beta-bookworm anon-beta-bullseye anon-beta-trixie anon-beta-noble anon-beta-jammy anon-beta-focal anon-beta-questing anon-beta-resolute anon-stage-bookworm anon-stage-bullseye anon-stage-trixie anon-stage-noble anon-stage-jammy anon-stage-focal anon-stage-questing anon-stage-resolute anon-dev-bookworm anon-dev-bullseye anon-dev-trixie anon-dev-noble anon-dev-jammy anon-dev-focal anon-dev-questing anon-dev-resolute anon-unstable-dev-bookworm anon-unstable-dev-bullseye anon-unstable-dev-trixie anon-unstable-dev-noble anon-unstable-dev-jammy anon-unstable-dev-focal anon-unstable-dev-questing anon-unstable-dev-resolute
    Cleanup: on_deny on_error unused_files
  EOH
}

job "anon-debian-repo" {
  datacenters = ["ator-fin"]
  type = "service"
  namespace = "live-services"

  constraint {
    attribute = "${meta.pool}"
    value = "live-services"
  }

  update {
    max_parallel      = 1
    healthy_deadline  = "15m"
    progress_deadline = "20m"
  }

  group "anon-debian-repo-nginx" {
    count = 1

    volume "deb-repo" {
      type      = "host"
      read_only = false
      source    = "deb-repo"
    }

    network {
      mode = "bridge"
      port "nginx-http" {
        to = 8080
        host_network = "wireguard"
      }
    }

    service {
      name = "anon-debian-repo-nginx"
      port = "nginx-http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.deb-repo-dns.entrypoints=https",
        "traefik.http.routers.deb-repo-dns.rule=Host(`deb.en.anyone.tech`)",
        "traefik.http.routers.deb-repo-dns.tls=true",
        "traefik.http.routers.deb-repo-dns.tls.certresolver=anyoneresolver"
      ]
      check {
        name     = "nginx http server alive"
        type     = "tcp"
        interval = "10s"
        timeout  = "10s"
        address_mode = "alloc"
        check_restart {
          limit = 10
          grace = "30s"
        }
      }
    }

    task "anon-debian-repo-nginx-task" {
      driver = "docker"

      volume_mount {
        volume      = "deb-repo"
        destination = "/data/debian"
        read_only   = false
      }

      config {
        image = "nginx:stable"
        ports = ["nginx-http"]
        volumes = [
          "local/default.conf:/etc/nginx/conf.d/default.conf:ro",
        ]
      }

      resources {
        cpu = 256
        memory = 512
      }

      template {
        change_mode = "noop"
        data = <<-EOH
        server {
            listen       8080;
            server_name  localhost;

            location /db/ {
                deny all;
                return 403;
            }

            location /conf/ {
                deny all;
                return 403;
            }

            location /incoming/ {
                deny all;
                return 403;
            }

            location / {
                location /pool/main/a/anon/ {
                  access_log /alloc/data/access.log;
                }

                root   /data/debian;
                autoindex on;
            }
        }
        EOH
        destination = "local/default.conf"
      }
    }
  }

  group "anon-debian-repo-package-exporter" {
    count = 1

    network {
      mode = "bridge"
      port "exporter-http" {
        to = 8080
        host_network = "wireguard"
      }
    }

    service {
      name = "anon-download-exporter"
      port = "exporter-http"
      check {
        name     = "anon download exporter alive"
        type     = "http"
        port     = "exporter-http"
        path     = "/"
        interval = "10s"
        timeout  = "10s"
        address_mode = "alloc"
        check_restart {
          limit = 10
          grace = "30s"
        }
      }
    }

    task "anon-package-exporter-task" {
      driver = "docker"

      config {
        image = "ghcr.io/anyone-protocol/package-exporter:v0.0.4"
        image_pull_timeout = "15m"
        ports = ["exporter-http"]
        volumes = [
          "local/exporter.yml:/app/config.yml:ro",
        ]
      }

      resources {
        cpu = 256
        memory = 256
      }

      template {
        change_mode = "noop"
        data = <<-EOH
        labels: [os, arch]
        fetchers:
          dockerhub_pulls:
            - name: anon_dev_dockerhub
              owner: svforte
              repo: anon-dev
            - name: anon_stage_dockerhub
              owner: svforte
              repo: anon-stage
            - name: anon_live_dockerhub
              owner: svforte
              repo: anon
          github_releases:
            - name: anon_dev_github_releases
              owner: anyone-protocol
              repo: ator-protocol
              assets_regexp: ^anon.+-dev-.+\.deb
              labels:
                os: 'anon.+(bookworm|bullseye|trixie|noble|jammy|focal|questing|resolute).+\.deb'
                arch: '(amd64|arm64)\.deb'
            - name: anon_stage_github_releases
              owner: anyone-protocol
              repo: ator-protocol
              assets_regexp: ^anon.+-stage-.+\.deb
              labels:
                os: 'anon.+(bookworm|bullseye|trixie|noble|jammy|focal|questing|resolute).+\.deb'
                arch: '(amd64|arm64)\.deb'
            - name: anon_beta_github_releases
              owner: anyone-protocol
              repo: ator-protocol
              assets_regexp: ^anon.+-beta-.+\.deb
              labels:
                os: 'anon.+(bookworm|bullseye|trixie|noble|jammy|focal|questing|resolute).+\.deb'
                arch: '(amd64|arm64)\.deb'
            - name: anon_live_github_releases
              owner: anyone-protocol
              repo: ator-protocol
              assets_regexp: ^anon.+-live-.+\.deb
              labels:
                os: 'anon.+(bookworm|bullseye|trixie|noble|jammy|focal|questing|resolute).+\.deb'
                arch: '(amd64|arm64)\.deb'
          nginx_access_log:
            - name: anon_dev_debian_repo
              access_log_path: "/alloc/data/access.log"
              access_log_regexp: '"GET /pool/.+anon_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-dev.+\.deb HTTP\/1\.1" 200'
              labels:
                os: 'anon.+(bookworm|bullseye|trixie|noble|jammy|focal|questing|resolute).+\.deb'
                arch: '(amd64|arm64)\.deb'
            - name: anon_stage_debian_repo
              access_log_path: "/alloc/data/access.log"
              access_log_regexp: '"GET /pool/.+anon_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-stage.+\.deb HTTP\/1\.1" 200'
              labels:
                os: 'anon.+(bookworm|bullseye|trixie|noble|jammy|focal|questing|resolute).+\.deb'
                arch: '(amd64|arm64)\.deb'
            - name: anon_beta_debian_repo
              access_log_path: "/alloc/data/access.log"
              access_log_regexp: '"GET /pool/.+anon_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-beta.+\.deb HTTP\/1\.1" 200'
              labels:
                os: 'anon.+(bookworm|bullseye|trixie|noble|jammy|focal|questing|resolute).+\.deb'
                arch: '(amd64|arm64)\.deb'
            - name: anon_live_debian_repo
              access_log_path: "/alloc/data/access.log"
              access_log_regexp: '"GET /pool/.+anon_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-live.+\.deb HTTP\/1\.1" 200'
              labels:
                os: 'anon.+(bookworm|bullseye|trixie|noble|jammy|focal|questing|resolute).+\.deb'
                arch: '(amd64|arm64)\.deb'
        EOH
        destination = "local/exporter.yml"
      }
    }
  }

  group "anon-debian-repo-reprepro" {

    volume "deb-repo" {
      type      = "host"
      read_only = false
      source    = "deb-repo"
    }

    network  {
      port "reprepro-ssh" {
        static = 22
      }
    }

    service {
      name = "anon-debian-repo-reprepro"
      port = "reprepro-ssh"
    }

    # Runs to completion before the main reprepro task starts. Drops the
    # package databases of distributions that were removed from
    # conf/distributions, so reprepro does not refuse to run after a
    # distribution is retired. clearvanished is a no-op when nothing vanished.
    task "anon-debian-repo-clearvanished-task" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      volume_mount {
        volume      = "deb-repo"
        destination = "/data/debian"
        read_only   = false
      }

      config {
        image      = "ghcr.io/anyone-protocol/reprepro:3e95599fe68eda3f808841a5568a9980fc2bb254"
        entrypoint = ["/bin/sh"]
        args       = ["/local/clearvanished.sh"]
        volumes = [
          "local/distributions:/data/debian/conf/distributions:ro",
          "local/incoming:/data/debian/conf/incoming:ro",
        ]
      }

      resources {
        cpu = 128
        memory = 128
      }

      template {
        change_mode = "noop"
        data        = <<-EOH
          #!/bin/sh
          set -ex
          if [ -d /data/debian/db ]; then
            owner="$(stat -c '%u:%g' /data/debian/db)"
            reprepro -b /data/debian --delete clearvanished
            chown -R "$owner" /data/debian/db
          else
            echo "no reprepro db yet, nothing to clear"
          fi
        EOH
        destination = "local/clearvanished.sh"
        perms       = "0755"
      }

      template {
        change_mode = "noop"
        data        = local.reprepro_distributions
        destination = "local/distributions"
      }

      template {
        change_mode = "noop"
        data        = local.reprepro_incoming
        destination = "local/incoming"
      }
    }

    task "anon-debian-repo-reprepro-task" {
      driver = "docker"

      volume_mount {
        volume      = "deb-repo"
        destination = "/data/debian"
        read_only   = false
      }

      config {
        image = "ghcr.io/anyone-protocol/reprepro:3e95599fe68eda3f808841a5568a9980fc2bb254"
        ports = ["reprepro-ssh"]
        volumes = [
          "local/distributions:/data/debian/conf/distributions:ro",
          "local/incoming:/data/debian/conf/incoming:ro",
          "secrets/config:/config:ro"
        ]
      }

      resources {
        cpu = 256
        memory = 256
      }

      vault {
        role = "any1-nomad-workloads-controller"
      }

      identity {
        name = "vault_default"
        aud  = ["any1-infra"]
        ttl  = "1h"
      }

      template {
        change_mode = "noop"
        data = <<-EOH
        {{ with secret "kv/live-services/anon-debian-repo" }}
        {{ base64Decode .Data.data.reprepro_sec }}
        {{ end }}
        EOH
        destination = "secrets/config/reprepro-sec.gpg"
        perms = "0600"
      }

      template {
        change_mode = "noop"
        data = <<-EOH
        {{ with secret "kv/live-services/anon-debian-repo" }}
        {{ base64Decode .Data.data.reprepro_pub }}
        {{ end }}
        EOH
        destination = "secrets/config/reprepro-pub.gpg"
        perms = "0600"
      }

      template {
        change_mode = "noop"
        data = <<-EOH
        {{ with secret "kv/live-services/anon-debian-repo" }}
        {{ base64Decode .Data.data.reprepro_authorized_keys }}
        {{ end }}
        EOH
        destination = "secrets/config/reprepro-authorized_keys"
      }

      template {
        change_mode = "noop"
        data        = local.reprepro_distributions
        destination = "local/distributions"
      }

      template {
        change_mode = "noop"
        data        = local.reprepro_incoming
        destination = "local/incoming"
      }
    }
  }
}
