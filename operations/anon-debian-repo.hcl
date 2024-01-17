job "anon-debian-repo" {
  datacenters = ["ator-fin"]
  type = "service"
  namespace = "ator-network"

  group "anon-debian-repo-group" {
    count = 1

    constraint {
      attribute = "${node.unique.id}"
      value     = "067a42a8-d8fe-8b19-5851-43079e0eabb4"
    }

    network  {
      port "reprepro-ssh" {
        static = 22
      }
    }

    task "anon-debian-repo-task" {
      driver = "docker"

      config {
        image = "svforte/reprepro:v0.0.4"
        ports = ["reprepro-ssh"]
        volumes = [
          "local/debian:/data/debian",
          "local/distributions:/data/debian/conf/distributions",
          "local/incoming:/data/debian/conf/incoming",
          "secrets/config:/config:ro"
        ]
      }

      vault {
        policies = ["ator-network-read"]
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
Codename: anon-nightly-main-bookworm
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Boookworm repository
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-nightly-main-bullseye
Architectures: amd64 arm64 source
Components: main
Description: Anon Debian Bullseye repository
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-nightly-main-jammy
Architectures: amd64 arm64 source
Components: main
Description: Anon Ubuntu Jammy repository
SignWith: YES

Origin: Anon
Label: Anon
Codename: anon-nightly-main-focal
Architectures: amd64 arm64 source
Components: main
Description: Anon Ubuntu Focal repository
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
Allow: anon-nightly-main-bookworm anon-nightly-main-bullseye anon-nightly-main-jammy anon-nightly-main-focal
Cleanup: on_deny on_error unused_files
        EOH
        destination = "local/incoming"
      }
    }
  }
}
