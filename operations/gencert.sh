#arguments working-dir ip nickname


mkdir -p $1 && cd $1

cat > torrc << EOL
# Run Tor as a regular user (do not change this)
User atord
DataDirectory /var/lib/tor

# Server's public IP Address (usually automatic)
Address $2

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

Nickname $3

EOL


docker run -i -w /var/lib/tor/keys -v ./torrc:/etc/tor/torrc -v ./tor-data:/var/lib/tor/ svforte/ator-protocol:latest tor-gencert --create-identity-key

ATOR_CONTAINER=$(docker create -v ./torrc:/etc/tor/torrc -v ./tor-data:/var/lib/tor/ svforte/ator-protocol:latest)
docker start $ATOR_CONTAINER 
sleep 5 
docker stop $ATOR_CONTAINER

sudo chown -R $USER:$USER .
sudo chmod -R 777 .

cd ..