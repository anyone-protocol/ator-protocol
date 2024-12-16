# Requirements:
# access to: consul, vault
# consul env: CONSUL_HTTP_ADDR, CONSUL_HTTP_TOKEN, CONSUL_CACERT
# installed: node

source_wallet_prv = 0xa74553f3eb7acef7c388da48ee97aca6c2d42710425316473754cd532f72a139
tokens_to_seed = 0.001

for i in {0..100}; do
    mkdir -p anon-family-relay-$i && cd anon-family-relay-$i

    #wallet
    node create-wallet.js wallet $source_wallet_prv $tokens_to_seed
    vault kv put -output-curl-string -mount=kv ator-network/stage/relay-family-$i \
            wallet_private_key="$(cat walletprv)" \
            wallet_phrase="$(cat walletmnem)" \
    consul kv put ator-network/stage/relay-family-$i/wallet "$(cat walletpub)"

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
