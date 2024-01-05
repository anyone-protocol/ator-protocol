## Private Anon network with ability to add new DA in production mode ##

This example provides ability to run private Anon network and change tha number and composition of directory authority list adding the new DA to the source code and rebuilding the image.

Copy predefined DA state (keys, fingerprint and configs) to temp anon folder
```
cp -r state anon
```

Create special docker image:
```
docker build . -t anon-local
```

To run a network execute:
```
docker compose up
```

It will start the private network setup with 3 DAs (using previously copied state)

Wait at least 30 mins until consensus will be created. (may take more than 1 hour to be built)

Each network participant's state is mounted to apropriate subfolder in temp `tor` directory

Anonrc file for each participant also mounted to the corresponding subfolder.

#### Add one more directory authority to consensus

Go to da4 state folder:
```
cd anon/da4
```
Generate DA keys:
```
docker run -i -w /var/lib/anon/keys \
  -v ./anonrc:/etc/anon/anonrc \
  -v ./anon-data:/var/lib/anon/ \
  svforte/anon:latest \
  anon-gencert --create-identity-key
chmod -R 777 anon-data/
```
Generate Relay keys and fingerprint:
```
ANON_CONTAINER=$(docker create \
  -v ./anonrc:/etc/anon/anonrc \
  -v ./anon-data:/var/lib/anon/ \
  svforte/anon:latest)
docker start $ANON_CONTAINER
sleep 5
docker stop $ANON_CONTAINER
chmod -R 777 anon-data/
```

Get fingerprints:

`anon-data/keys/authority_certificate`  – contains DA identity fingerprint

`anon-data/fingerprint` – contains relay fingerprint

Create Record in auth_dirs.inc (in examples/da dir) for new DA:

```
"da4 orport=9001 "
  "v3ident=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "
  "172.0.0.14:9030 FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
```

`AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA` – Directory Authority Identity Fingerprint

`FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF` – Relay Fingerprint

Go back to project folder:
```
cd ../..
```

Copy keys to tor mounted folder to be used in container
```
cp -r anon/da4/anon-data/keys tor/da4/keys
```

Remove temporary anon-data directory
```
rm -rf anon/da4/anon-data
```

Rebuild docker image with new DA:
```
docker build . -t anon-local --no-cache
```

Run new DA connecting to the existing compose network, specific port and volumes:
```
docker run  --network=da_local --ip=172.0.0.14 -v ./anon/da4:/var/lib/anon/ -v ./anon/da4:/etc/anon anon-local
```

(Optional) Wait until new DA will be listed as a relay in consensus

Update container in compose to use new version of the image (with new DA hardcoded):
```
docker-compose up -d
```

Wait until existed DA will vote for new DA and it will be listed in consensus
