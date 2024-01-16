

#STAGE
bash gencert.sh da1 49.13.145.234 ATORDAeucstage
bash gencert.sh da2 5.161.108.187 ATORDAusestage
bash gencert.sh da3 49.13.145.234 ATORDAuswstage

bash uploadcert.sh da1/tordata/keys 067a42a8-d8fe-8b19-5851-43079e0eabb4 49.13.145.234 ATORDAeucstage
bash uploadcert.sh da2/tordata/keys 16be0723-edc1-83c4-6c02-193d96ec308a 5.161.108.187 ATORDAusestage
bash uploadcert.sh da3/tordata/keys e6e0baed-8402-fd5c-7a15-8dd49e7b60d9 49.13.145.234 ATORDAuswstage

