# Requirements:
# access to: consul, vault
# consul env: CONSUL_HTTP_ADDR, CONSUL_HTTP_TOKEN, CONSUL_CACERT
# STAGE by default in scripts

### -- STEP 1 ---

## DEV

for i in {0..100}; do
    bash gencert-101relay.sh anon-family-relay-$i AnonFamilyRelay$i
done

### -- STEP 2 ---
# Check/update script for phase


for i in {0..100}; do
    bash uploadcert-101relay.sh anon-family-relay-$i $i
done

### -- STEP 3 ---
# mind the phase....
# Move DA folders and script to server, login, run script

for i in {0..100}; do
    bash uploadcert-101relay.sh anon-family-relay-$i $i
done