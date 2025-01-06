locals {
  instances_count = 100
  nicnname_prefix = "AnonFamilyRelay"
	nicknames = [for i in range(0, local.instances_count) : "${local.nicnname_prefix}${i}"]
	nicknames_string = join(",", local.nicknames)
}


job "relays-family-stage" {
  datacenters = ["ator-fin"]
  type = "service"
  namespace = "ator-network"

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
        data = <<EOH
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
    
    task "registerhardware" {
			driver = "docker"        
	    lifecycle {
  	    hook = "poststart"
    	  sidecar = false
    	}
			config { 
        image = "curlimages/curl" 
        command = "curl"            
        args = ["--header", "Content-Type: application/json", "--fail", "--data", "@post.json", "--location", "https://api-stage.ec.anyone.tech/hardware"] 
  			volumes = [
          "local/post:/home/curl_user/post.json"
        ]        
      }
      template {
        change_mode = "noop"
        data = <<EOH
{
    "id": "HWrelay",
    "company": "anyone.io",
    "format": "broadcast-type:1",
    "wallet": "{{ key (env `NOMAD_ALLOC_INDEX` | printf `ator-network/stage/relay-family-%s/wallet`) }}",
    {{ $fingerprint := key (env `NOMAD_ALLOC_INDEX` | printf `ator-network/stage/relay-family-%s/fingerprint`) | split " " }}
	  {{- range $index, $element := $fingerprint }} {{- if eq $index 1 }}"fingerprint": "{{ $element  }}",{{- end }} {{- end }}
    "nftid":"12345",
    "build":"2.0.1",
    "flags":"33",
    "serNums": [
        {
            "type": "DEVICE",
            "number": "c2eeef8a42a50073"
        },
        {
            "type": "ATEC",
            "number": "0123d4fb782ded6101"
        }
    ],
    "pubKeys": [
        {
            "type": "DEVICE",
            "number": "3a4a8debb486d32d438f38cf24f8b723326fb85cf9c15a2a7f9bc80916dd8d7de8b9990a8fc0a12e72fd990b3569bbbf24970b07a024a03fa51e5b719fe921bf"
        },
        {
            "type": "SIGNER",
            "number": "4aa155e5c04759c5a82cafa7657bc32cc2fecd8eba5f06d0bb2b6709901108e0958ce41737cd4fbf473f5862a81e95a23979bd9083d1c5fe4cc9ceb1ef9c3735"
        }
    ],
    "certs": [
        {
            "type": "DEVICE",
            "signature": "4A B7 B1 E1 7A 8F 7D 8D 68 CB 5D 42 33 B2 4C 9F 55 96 28 56 27 82 C7 DE DF 82 A5 7F 90 0C 3F 6F 1E FE 2F 5B 4F 6C 1D 96 76 54 E2 63 7E 86 8C B3 57 2D 3E 2C 28 58 51 43 23 CD 40 99 6B B4 F2 C3"
        }
    ]
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
