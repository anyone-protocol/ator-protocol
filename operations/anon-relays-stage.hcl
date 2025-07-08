locals {
  instances_count = 100
  nicnname_prefix = "AnonFamilyRelay"
	nicknames = [for i in range(0, local.instances_count) : "${local.nicnname_prefix}${i}"]
	nicknames_string = join(",", local.nicknames)
}

job "anon-relays-stage" {
  datacenters = ["ator-fin"]
  type = "service"
  namespace = "stage-network"

  constraint {
    attribute = "${meta.pool}"
    value = "stage"
  }

  group "relay-live-group" {
    count = local.instances_count
    
    spread {
      attribute = "${node.unique.id}"
      weight    = 100
      target "f3f664d6-7d65-be58-4a2c-4c66e20f1a9f" {
        percent = 33
      }
      target "232ea736-591c-4753-9dcc-3e815c4326af" {
        percent = 33
      }
      target "4ca2fc3c-8960-6ae7-d931-c0d6030d506b" {
        percent = 34
      }
  	}

    # constraint {
    #   attribute = "${node.unique.id}"
    #   operator  = "set_contains_any"
    #   value     = "4ca2fc3c-8960-6ae7-d931-c0d6030d506b,232ea736-591c-4753-9dcc-3e815c4326af,f3f664d6-7d65-be58-4a2c-4c66e20f1a9f"
    # }

    network  {
      port "orport" {
        static = 0
      }     
    }

    task "anon-relays-stage-task" {
      driver = "docker"    

      config {
        image = "ghcr.io/anyone-protocol/ator-protocol-stage:4b413cc6c0c82e4baefeb3545efe5bc416913700"
        ports = ["orport"]
        volumes = [
          "local/anonrc:/etc/anon/anonrc",
          "secrets/anon/keys:/var/lib/anon/keys"
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
           {{ key (env `NOMAD_ALLOC_INDEX` | printf `ator-network/stage/relay-family-%s/authority_certificate`) }}
        EOH
        destination = "secrets/anon/keys/authority_certificate"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{ .Data.data.authority_identity_key}}{{end}}"
        destination = "secrets/anon/keys/authority_identity_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{.Data.data.authority_signing_key}}{{end}}"
        destination = "secrets/anon/keys/authority_signing_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{ base64Decode .Data.data.ed25519_master_id_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_master_id_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{ base64Decode .Data.data.ed25519_signing_secret_key_base64}}{{end}}"
        destination = "secrets/anon/keys/ed25519_signing_secret_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{ base64Decode .Data.data.secret_id_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_id_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{ base64Decode .Data.data.secret_onion_key_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key"
      }

      template {
        change_mode = "noop"
        data = "{{ with secret  (env `NOMAD_ALLOC_INDEX` | printf `kv/ator-network/stage/relay-family-%s`) }}{{ base64Decode .Data.data.secret_onion_key_ntor_base64}}{{end}}"
        destination = "secrets/anon/keys/secret_onion_key_ntor"
      }

      template {
        change_mode = "noop"
        data = <<-EOH
        User anond
        DataDirectory /var/lib/anon

        AgreeToTerms 1

        ORPort {{ env `NOMAD_PORT_orport` }}

        RelayBandwidthRate {{ key (env `NOMAD_ALLOC_INDEX` | printf `ator-network/stage/relay-family-%s/bandwidth`) }}
        ExitRelay {{ key (env `NOMAD_ALLOC_INDEX` | printf `ator-network/stage/relay-family-%s/isexit`) }}
                
        Nickname {{ env `NICKNAME_PREFIX` }}{{ env `NOMAD_ALLOC_INDEX` }}
        ContactInfo anon@example.org @anon: {{ key (env `NOMAD_ALLOC_INDEX` | printf `ator-network/stage/relay-family-%s/wallet`) }}
        EOH
        destination = "local/anonrc"
      }    
    }
    
    task "anon-relays-stage-register-hardware-task" {
			driver = "docker"        
	    lifecycle {
  	    hook = "poststart"
    	  sidecar = false
    	}
			config { 
        image = "curlimages/curl" 
        command = "curl"            
        args = [
          "--header", "Content-Type: application/json",
          "--fail",
          "--data", "@post.json",
          "--location", "https://api-stage.ec.anyone.tech/hardware"
        ]
  			volumes = [
          "local/post:/home/curl_user/post.json"
        ]        
      }
      template {
        change_mode = "noop"
        data = <<-EOH
        {
          "id": "HWrelay",
          "company": "anyone.io",
          "format": "broadcast-type:1",
          "wallet": "{{ key (env `NOMAD_ALLOC_INDEX` | printf `ator-network/stage/relay-family-%s/wallet`) }}",
          {{ $fingerprint := key (env `NOMAD_ALLOC_INDEX` | printf `ator-network/stage/relay-family-%s/fingerprint`) | split " " }}
          {{- range $index, $element := $fingerprint }} {{- if eq $index 1 }}"fingerprint": "{{ $element  }}",{{- end }} {{- end }}
          "nftid": "12345",
          "build": "2.0.1",
          "flags": "33",
          {{ with secret "kv/ator-network/stage/relay-family-example-hardware" }}
          "serNums": [
            {
              "type": "DEVICE",
              "number": "{{ .Data.data.DEVICE_SER_NUM }}"
            },
            {
              "type": "ATEC",
              "number": "{{ .Data.data.ATEC_SER_NUM }}"
            }
          ],
          "pubKeys": [
            {
              "type": "DEVICE",
              "number": "{{ .Data.data.DEVICE_PUBKEY }}"
            },
            {
              "type": "SIGNER",
              "number": "{{ .Data.data.SIGNER_PUBKEY }}"
            }
          ],
          "certs": [
            {
              "type": "DEVICE",
              "signature": "{{ .Data.data.DEVICE_CERT_SIGNATURE }}"
            }
          ]
          {{ end }}
        }
        EOH
        destination = "local/post"
      }    
      
      resources { 
        cpu = 100 
        memory = 128 
      }      
    }
  }
}
