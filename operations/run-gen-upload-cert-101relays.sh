# Requirements:
# access to: consul, vault
# consul env: CONSUL_HTTP_ADDR, CONSUL_HTTP_TOKEN, CONSUL_CACERT
# STAGE by default in scripts

for i in {0..100}; do
    bash gencert-101relays.sh anon-family-relay-$i AnonFamilyRelay$i
    bash uploadcert-101relays.sh anon-family-relay-$i $i
    bash uploadcert-101relays.sh anon-family-relay-$i $i
done
