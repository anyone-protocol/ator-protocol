# Requirements:
# access to: consul, vault
# consul env: CONSUL_HTTP_ADDR, CONSUL_HTTP_TOKEN, CONSUL_CACERT
# installed: node

source_wallet_prv=0xb7b5e3f3eb7acef7c388da48ee97aca6c2d4d750c2f3d6f73754cd532f72a139
tokens_to_seed=0.001

for i in {11..100}; do
    mkdir -p anon-family-relay-$i && cd anon-family-relay-$i

    #wallet
    node ../create-wallet.js wallet $source_wallet_prv $tokens_to_seed

    consul kv put ator-network/stage/relay-family-$i/wallet "$(cat walletpub)"
    consul kv put ator-network/stage/relay-family-$i/wallet_private_key "$(cat walletprv)"
    consul kv put ator-network/stage/relay-family-$i/wallet_phrase "$(cat walletmnem)"

    #bandwidth
    bandwidth=$(( 500 + (i * 100) ))
    consul kv put ator-network/stage/relay-family-$i/bandwidth "${bandwidth} KBytes"

    #exit
    if [ $i -ge 80 ] && [ $i -le 90 ]; then
        consul kv put ator-network/stage/relay-family-$i/isexit "1";
    else
        consul kv put ator-network/stage/relay-family-$i/isexit "0";
    fi
    #

    cd ..
done
