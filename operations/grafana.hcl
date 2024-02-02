job "grafana" {
    datacenters = ["ator-fin"]
    type = "service"
    namespace = "ator-network"

    group "grafana-group" {
        count = 1

        spread {
            attribute = "${node.unique.id}"
            weight    = 100
            target "067a42a8-d8fe-8b19-5851-43079e0eabb4" {
                percent = 100
            }
        }

        // volume "grafana_data" {
        //     type      = "host"
        //     read_only = false
        //     source    = "grafana_data"
        // }

        // ephemeral_disk {
        //     migrate = true
        //     sticky  = true
        // }

        network {
            mode = "bridge"
            port "http" {
                to = 3000
                host_network = "wireguard"
             }
        }
    
        task "grafana-task" {
            driver = "docker"

            // volume_mount {
            //     volume      = "grafana_data"
            //     destination = "/var/lib/grafana/"
            //     read_only   = false
            // }

            config {
                image = "grafana/grafana:latest"
                volumes = [
                    "local/datasources.yaml:/etc/grafana/provisioning/datasources/datasources.yaml"
                ]             
            }

            vault {
              	policies = ["ator-network-read"]
      	    }

            resources {
                cpu = 256
                memory = 256
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