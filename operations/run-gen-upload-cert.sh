# Requirements:
# have: docker, consul, vault
# consul env: CONSUL_HTTP_ADDR, CONSUL_HTTP_TOKEN, CONSUL_CACERT

# STAGE by default in scripts
bash gencert.sh da1 49.13.145.234 ATORDAeucstage
bash gencert.sh da2 5.161.108.187 ATORDAusestage
bash gencert.sh da3 49.13.145.234 ATORDAuswstage

bash gencert.sh da4 5.161.228.187 AnyoneAshLive
bash gencert.sh da5 5.78.94.15 AnyoneHilLive

bash uploadcert.sh da1 067a42a8-d8fe-8b19-5851-43079e0eabb4 49.13.145.234 ATORDAeucstage
bash uploadcert.sh da2 16be0723-edc1-83c4-6c02-193d96ec308a 5.161.108.187 ATORDAusestage
bash uploadcert.sh da3 e6e0baed-8402-fd5c-7a15-8dd49e7b60d9 49.13.145.234 ATORDAuswstage

bash uploadcert.sh da4 5ace4a92-63c4-ac72-3ed1-e4485fa0d4a4 5.161.228.187 AnyoneAshLive
bash uploadcert.sh da5 eb42c498-e7a8-415f-14e9-31e9e71e5707 5.78.94.15 AnyoneHilLive

# Move DA folders and script to server, login, run script
# bash uploadsecrets.sh da1 067a42a8-d8fe-8b19-5851-43079e0eabb4
# bash uploadsecrets.sh da2 16be0723-edc1-83c4-6c02-193d96ec308a
# bash uploadsecrets.sh da3 e6e0baed-8402-fd5c-7a15-8dd49e7b60d9

# bash uploadsecrets.sh da4 5ace4a92-63c4-ac72-3ed1-e4485fa0d4a4
# bash uploadsecrets.sh da5 eb42c498-e7a8-415f-14e9-31e9e71e5707