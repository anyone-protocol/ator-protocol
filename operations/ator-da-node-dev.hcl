job "ator-da-node-dev1" {
  datacenters = ["dc1"]
  type = "service" 
  group "da1" {
    network  {
      port "p1" {
        to = 9001
      }
      port "p2" {
        to = 9030
      }

    }
    count = 1
    volume "ator" {
      type      = "host"
      read_only = false
      source    = "ator"
    }    

    update {
      max_parallel = 1
      health_check = "checks"
      min_healthy_time  = "30s"
      healthy_deadline = "2m"
      auto_revert = true
      auto_promote = true
      canary = 2
    }
  
    task "da" {
      driver = "docker"
    
      volume_mount {
        volume      = "ator"
        destination = "/var/lib/tor/"
        read_only   = false
      } 
          
      config {
        image = "svforte/ator-protocol:42c6db411a6d3cdffafcc6e09cf4ad4d5aa23456"
        ports = ["p1", "p2"]
        volumes = [
          "local/torrc:/etc/tor/torrc"
        ]
      }

      resources {
        cpu = 500
        memory = 256
      }  

      template {
        data = <<EOH
          ##=================== /etc/torrc =====================##
          # see /usr/local/etc/tor/torrc.sample and https://www.torproject.org/docs/tor-manual.html.en

          # Run Tor as a regular user (do not change this)
          User atord
          DataDirectory /var/lib/tor

          # Server's public IP Address (usually automatic)
          #Address 10.10.10.10

          # Port to advertise for incoming Tor connections.
          ORPort 9001                  # common ports are 9001, 443
          #ORPort [IPv6-address]:9001

          # Mirror directory information for others (optional, not used on bridge)
          DirPort 9030                 # common ports are 9030, 80

          # Run Tor only as a server (no local applications)
          SocksPort 0
          ControlSocket 0

          # Run as a relay only (change policy to enable exit node)
          ExitPolicy reject *:*        # no exits allowed
          ExitPolicy reject6 *:*
          ExitRelay 0
          IPv6Exit 0
          
          # Set limits
          #AccountingMax 999 GB
          #RelayBandwidthRate 512 KB   # Throttle traffic to
          #RelayBandwidthBurst 1024 KB # But allow bursts up to
          #MaxMemInQueues 512 MB       # Limit Memory usage to
          
          ## Run Tor as obfuscated bridge
          # https://trac.torproject.org/projects/tor/wiki/doc/PluggableTransports/obfs4proxy
          #ServerTransportPlugin obfs4 exec /usr/local/bin/obfs4proxy
          #ServerTransportListenAddr obfs4  0.0.0.0:54444
          #ExtORPort auto
          #BridgeRelay 1
          
          ## If no Nickname or ContactInfo is set, docker-entrypoint will use
          ## the environment variables to add Nickname/ContactInfo below
          #Nickname ATORv4example          # only use letters and numbers
          #ContactInfo atorv4@example.org
        EOH
        destination = "local/torrc"
      }
    }    
  }
}