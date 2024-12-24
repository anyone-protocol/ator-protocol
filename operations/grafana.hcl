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
			
			
			vault {
				policies = ["smtp-mailer"]
			}


            volume_mount {
                volume      = "grafana"
                destination = "/var/lib/grafana"
                read_only   = false
            }

            config {
                image = "grafana/grafana:latest"
                volumes = [
                    "local/datasources.yaml:/etc/grafana/provisioning/datasources/datasources.yaml",
					"local/grafana.ini:/etc/grafana/grafana.ini"
                ]             
            }
          
            resources {
                cpu = 1024
                memory = 4096
            }  

            template {
                change_mode = "noop"
                data = <<EOF
[plugins]
allow_loading_unsigned_plugins = victoriametrics-datasource

[smtp]
enabled = true
host = smtp.mailgun.org:587
{{with secret "kv/smtp-mailer"}}
user = {{.Data.data.AUTH_USER}}
password = {{.Data.data.AUTH_PASSWORD}}
{{end}}
skip_verify = false
from_address = alerts@ator.io
from_name = Ator Alerts
EOF
                destination = "local/grafana.ini"
            }

            template {
                change_mode = "noop"
                data = <<EOF
apiVersion: 1
datasources:
- name: victoriametrics
  type: victoriametrics-datasource
  access: proxy
{{- range nomadService "victoriametrics-db" }}
  url: http://{{ .Address }}:{{ .Port }}
  isDefault: true
{{ end -}}
- name: Loki
  type: loki
  access: proxy
{{- range nomadService "loki" }}
  url: http://{{ .Address }}:{{ .Port }}
{{ end -}}  
  jsonData:
    timeout: 60
    maxLines: 1000
EOF
                destination = "local/datasources.yaml"
            }
        }
      
        service {
            name = "grafana"
            port = "http"
			check {
			  name     = "grafana-health"
			  type     = "http"
			  path     = "/api/health"
			  interval = "15s"
			  timeout  = "10s"
			  check_restart {
				limit = 3
				grace = "10s"
			  }
			}
        }      
    }
}
