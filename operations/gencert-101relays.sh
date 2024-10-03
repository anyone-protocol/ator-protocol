#arguments working-dir nickname


mkdir -p $1 && cd $1

cat > anonrc << EOL
User anond
DataDirectory /var/lib/anon

AgreeToTerms 1

ORPort 8081

Nickname $2
ContactInfo anon@anon.com

EOL


docker run -i -w /var/lib/anon/keys -v ./anonrc:/etc/anon/anonrc -v ./anon-data:/var/lib/anon/ ghcr.io/anyone-protocol/ator-protocol-stage:latest anon-gencert --create-identity-key

ATOR_CONTAINER=$(docker create -v ./anonrc:/etc/anon/anonrc -v ./anon-data:/var/lib/anon/ ghcr.io/anyone-protocol/ator-protocol-stage:latest)
docker start $ATOR_CONTAINER 
sleep 5 
docker stop $ATOR_CONTAINER

sudo chown -R $USER:$USER .
sudo chmod -R 777 .

cd ..