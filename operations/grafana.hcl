job "grafana" {
    datacenters = ["ator-fin"]
    type = "service"
    namespace = "ator-network"

    group "grafana-group" {
        count = 1

        volume "grafana" {
            type      = "host"
            read_only = false
            source    = "grafana"
        }

        network {
            mode = "bridge"
            port "http" {
                static = 3000
                host_network = "wireguard"
             }
        }
    
        task "grafana-task" {
            driver = "docker"


        env {
          GF_LOG_LEVEL          = "DEBUG"
          GF_LOG_MODE           = "console"
        }

            volume_mount {
                volume      = "grafana"
                destination = "/var/lib/grafana"
                read_only   = false
            }

            config {
                image = "grafana/grafana:latest"
                volumes = [
                    "local/datasources.yaml:/etc/grafana/provisioning/datasources/datasources.yaml"
                ]             
            }
          
            resources {
                cpu = 2048
                memory = 2048
            }  

            template {
                change_mode = "noop"
                data = <<EOF
apiVersion: 1
datasources:
- name: victoriametrics
  type: prometheus
  access: proxy
{{- range nomadService "victoriametrics-db" }}
  url: http://{{ .Address }}:{{ .Port }}
  isDefault: true
{{ end -}}
EOF
                destination = "local/datasources.yaml"
            }
      
        }
      
        service {
            name = "grafana"
            port = "http"      
        }      
    }
}