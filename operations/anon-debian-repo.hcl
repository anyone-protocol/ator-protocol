job "anon-debian-repo" {
  datacenters = ["ator-fin"]
  type = "service"
  namespace = "live-services"

  update {
    max_parallel      = 1
    healthy_deadline  = "15m"
    progress_deadline = "20m"
  }

  group "anon-debian-repo-group" {
    count = 1

    constraint {
      attribute = "${node.unique.id}"
      value     = "c8e55509-a756-0aa7-563b-9665aa4915ab"
    }

    volume "deb-repo" {
      type      = "host"
      read_only = false
      source    = "deb-repo"
    }

    network  {
      port "reprepro-ssh" {
        static = 22
      }
      port "nginx-http" {
        static = 8001
      }
      port "exporter-http" {
        static = 8002
        to = 8080
      }
    }

    ephemeral_disk {
      migrate = true
      sticky  = true
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
          check_restart {
            limit = 10
            grace = "30s"
          }
        }
      }

      template {
        change_mode = "noop"
        data = <<EOH
server {
    listen       8001;
    listen  [::]:8001;
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
          check_restart {
            limit = 10
            grace = "30s"
          }
        }
      }

      resources {
        cpu = 256
        memory = 256
      }

      template {
        change_mode = "noop"
        data = <<EOH
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
        os: 'anon.+(bookworm|bullseye|oracular|noble|jammy|focal).+\.deb'
        arch: '(amd64|arm64)\.deb'
    - name: anon_stage_github_releases
      owner: anyone-protocol
      repo: ator-protocol
      assets_regexp: ^anon.+-stage-.+\.deb
      labels:
        os: 'anon.+(bookworm|bullseye|oracular|noble|jammy|focal).+\.deb'
        arch: '(amd64|arm64)\.deb'
    - name: anon_beta_github_releases
      owner: anyone-protocol
      repo: ator-protocol
      assets_regexp: ^anon.+-beta-.+\.deb
      labels:
        os: 'anon.+(bookworm|bullseye|oracular|noble|jammy|focal).+\.deb'
        arch: '(amd64|arm64)\.deb'
    - name: anon_live_github_releases
      owner: anyone-protocol
      repo: ator-protocol
      assets_regexp: ^anon.+-live-.+\.deb
      labels:
        os: 'anon.+(bookworm|bullseye|oracular|noble|jammy|focal).+\.deb'
        arch: '(amd64|arm64)\.deb'
  nginx_access_log:
    - name: anon_dev_debian_repo
      access_log_path: "/alloc/data/access.log"
      access_log_regexp: '"GET /pool/.+anon_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-dev.+\.deb HTTP\/1\.1" 200'
      labels:
        os: 'anon.+(bookworm|bullseye|oracular|noble|jammy|focal).+\.deb'
        arch: '(amd64|arm64)\.deb'
    - name: anon_stage_debian_repo
      access_log_path: "/alloc/data/access.log"
      access_log_regexp: '"GET /pool/.+anon_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-stage.+\.deb HTTP\/1\.1" 200'
      labels:
        os: 'anon.+(bookworm|bullseye|oracular|noble|jammy|focal).+\.deb'
        arch: '(amd64|arm64)\.deb'
    - name: anon_beta_debian_repo
      access_log_path: "/alloc/data/access.log"
      access_log_regexp: '"GET /pool/.+anon_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-beta.+\.deb HTTP\/1\.1" 200'
      labels:
        os: 'anon.+(bookworm|bullseye|oracular|noble|jammy|focal).+\.deb'
        arch: '(amd64|arm64)\.deb'
    - name: anon_live_debian_repo
      access_log_path: "/alloc/data/access.log"
      access_log_regexp: '"GET /pool/.+anon_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-live.+\.deb HTTP\/1\.1" 200'
      labels:
        os: 'anon.+(bookworm|bullseye|oracular|noble|jammy|focal).+\.deb'
        arch: '(amd64|arm64)\.deb'
        EOH
        destination = "local/exporter.yml"
      }
    }

    task "anon-debian-repo-task" {
      driver = "docker"

      volume_mount {
        volume      = "deb-repo"
        destination = "/data/debian"
        read_only   = false
      }

      config {
        image = "svforte/reprepro:v0.0.6"
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

      service {
        name = "anon-debian-repo-reprepro"
        port = "reprepro-ssh"
        check {
          name     = "reprepro ssh server alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "10s"
          check_restart {
            limit = 10
            grace = "30s"
          }
        }
      }

      template {
        change_mode = "noop"
        data = <<EOH
{{ base64Decode "[[.reprepro_sec]]" }}
        EOH
        destination = "secrets/config/reprepro-sec.gpg"
        perms = "0600"
      }

      template {
        change_mode = "noop"
        data = <<EOH
{{ base64Decode "[[.reprepro_pub]]" }}
        EOH
        destination = "secrets/config/reprepro-pub.gpg"
        perms = "0600"
      }

      template {
        change_mode = "noop"
        data = <<EOH
{{ base64Decode "[[.authorized_keys]]" }}
        EOH
        destination = "secrets/config/reprepro-authorized_keys"
      }

      template {
        change_mode = "noop"
        data = <<EOH
Origin: Anon
Label: Anon
Codename: anon-live-bookworm
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Boookworm Live
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
Codename: anon-live-oracular
Architectures: amd64 arm64 source
Components: main
DDebComponents: main
Description: Anon Ubuntu Oracular Live
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
Codename: anon-beta-bookworm
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Boookworm Beta
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
Codename: anon-beta-oracular
Architectures: amd64 arm64 source
Components: main
DDebComponents: main
Description: Anon Ubuntu Oracular Beta
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
Codename: anon-stage-bookworm
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Boookworm Stage
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
Codename: anon-stage-oracular
Architectures: amd64 arm64 source
Components: main
DDebComponents: main
Description: Anon Ubuntu Oracular Stage
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
Codename: anon-dev-bookworm
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Boookworm Dev
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
Codename: anon-dev-oracular
Architectures: amd64 arm64 source
Components: main
DDebComponents: main
Description: Anon Ubuntu Oracular Dev
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
Codename: anon-unstable-dev-bookworm
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Boookworm Unstable Dev
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
Codename: anon-unstable-dev-oracular
Architectures: amd64 arm64 source
Components: main
DDebComponents: main
Description: Anon Ubuntu Oracular Unstable Dev
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
        EOH
        destination = "local/distributions"
      }

      template {
        change_mode = "noop"
        data = <<EOH
Name: incoming
IncomingDir: /data/debian/incoming
TempDir: /tmp
Allow: anon-live-bookworm anon-live-bullseye anon-live-oracular anon-live-noble anon-live-jammy anon-live-focal anon-beta-bookworm anon-beta-bullseye anon-beta-oracular anon-beta-noble anon-beta-jammy anon-beta-focal anon-stage-bookworm anon-stage-bullseye anon-stage-oracular anon-stage-noble anon-stage-jammy anon-stage-focal anon-dev-bookworm anon-dev-bullseye anon-dev-oracular anon-dev-noble anon-dev-jammy anon-dev-focal anon-unstable-dev-bookworm anon-unstable-dev-bullseye anon-unstable-dev-oracular anon-unstable-dev-noble anon-unstable-dev-jammy anon-unstable-dev-focal
Cleanup: on_deny on_error unused_files
        EOH
        destination = "local/incoming"
      }
    }
  }
}