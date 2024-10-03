# Requirements:
# access to: consul, vault
# consul env: CONSUL_HTTP_ADDR, CONSUL_HTTP_TOKEN, CONSUL_CACERT
# STAGE by default in scripts

for i in {0..100}; do
    bash gencert-101relay.sh anon-family-relays-$i AnonFamilyRelay$i
    bash uploadcert-101relay.sh anon-family-relays-$i $i
    bash uploadcert-101relay.sh anon-family-relays-$i $i
done
