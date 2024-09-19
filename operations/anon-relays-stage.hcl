locals {
  instances_count = 3
  nicnname_prefix = "anonW12fqj5t5FML"
	nicknames = [for i in range(0, local.instances_count) : "${local.nicnname_prefix}${i}"]
	nicknames_string = join(",", local.nicknames)
}


job "relays-family-stage" {
  datacenters = ["ator-fin"]
  type = "service"
  namespace = "ator-network"

  group "relay-live-group" {
    count = local.instances_count

    constraint {
        attribute = "${node.unique.id}"
        operator  = "set_contains_any"
        value     = "4ca2fc3c-8960-6ae7-d931-c0d6030d506b,232ea736-591c-4753-9dcc-3e815c4326af,f3f664d6-7d65-be58-4a2c-4c66e20f1a9f"
    }

    network  {
      port "orport" {
        static = 0
      }     
    }

    task "relay-live-task" {
      driver = "docker"    

      config {
        image = "ghcr.io/anyone-protocol/ator-protocol-stage:latest"
        ports = ["orport"]
        volumes = [
          "local/anonrc:/etc/anon/anonrc",
        ]
      }
      
      env {
				NICKNAMES_STRING = local.nicknames_string
        NICKNAME_PREFIX = local.nicnname_prefix
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
        data = <<EOH
User anond
DataDirectory /var/lib/anon

AgreeToTerms 1

ORPort {{ env `NOMAD_PORT_orport` }}

Nickname {{ env `NICKNAME_PREFIX` }}{{ env `NOMAD_ALLOC_INDEX` }}
ContactInfo anon@example.org
MyFamily {{ env `NICKNAMES_STRING` }}
        EOH
        destination = "local/anonrc"
      }    
    }
  }
}
