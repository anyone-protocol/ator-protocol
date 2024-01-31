job "anon-monitoring-stage" {
    datacenters = ["ator-fin"]

    #temp
    group "monitoring-stage-group-prometheus" {
        network {
            mode = "bridge"
        }

        service {
            name = "prometheus"
            port = "9190"

            connect {
                sidecar_service {}
            }
        }

        task "web" {
            driver = "docker"
            config {
                image = "prom/prometheus:latest"
            }
        }
    }


    group "monitoring-stage-group-grafana" {
        network {
            mode ="bridge"
            port "http" {
                static = 9180
                to     = 9180
            }
        }

        service {
            name = "grafana"
            port = "9180"

            connect {
                    sidecar_service {
                    proxy {
                        upstreams {
                            destination_name = "prometheus"
                            local_bind_port  = 9190
                        }
                    }
                }
            }
        }

        task "dashboard" {
            driver = "docker"
            config {
                image = "grafana/grafana:latest"
            }
        }
    }
}