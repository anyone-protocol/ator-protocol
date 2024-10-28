# Requirements:
# access to: consul, vault
# consul env: CONSUL_HTTP_ADDR, CONSUL_HTTP_TOKEN, CONSUL_CACERT
# STAGE by default in scripts

### -- STEP 1 ---

## LIVE
# bash gencert.sh da1 49.13.145.234 ATORDAeucstage
# bash gencert.sh da2 5.161.108.187 ATORDAusestage
# bash gencert.sh da3 5.78.90.106 ATORDAuswstage
# bash gencert.sh da4 5.161.228.187 AnyoneAshLive
# bash gencert.sh da5 5.78.94.15 AnyoneHilLive
# bash gencert.sh da6 95.216.32.105 AnyoneHelLive
# bash gencert.sh da7 176.9.29.53 AnyoneFalLive

## STAGE
# bash gencert.sh stage-da1-hel-test-1a 135.181.231.123 AnyoneHel1aStage
# bash gencert.sh stage-da2-hel-test-2a 148.251.23.105 AnyoneHel2aStage
# bash gencert.sh stage-da3-hel-test-3a 65.21.12.154 AnyoneHel3aStage

# bash gencert.sh stage-da2-hel-test-2b 148.251.23.105 AnyoneHel2bStage
# bash gencert.sh stage-da3-hel-test-3b 65.21.12.154 AnyoneHel3bStage
# bash gencert.sh stage-da2-hel-test-2c 148.251.23.105 AnyoneHel2cStage
# bash gencert.sh stage-da3-hel-test-3c 65.21.12.154 AnyoneHel3cStage

## DEV
# bash gencert.sh dev-da1-dmz 88.99.219.105 AnyoneDmzDev
# bash gencert.sh dev-da2-fal 176.9.29.53 AnyoneFalDev
# bash gencert.sh dev-da3-hel 95.216.32.105 AnyoneHelDev


### -- STEP 2 ---
# Check/update script for phase

## LIVE
# bash uploadcert.sh da1 067a42a8-d8fe-8b19-5851-43079e0eabb4 49.13.145.234 ATORDAeucstage
# bash uploadcert.sh da2 16be0723-edc1-83c4-6c02-193d96ec308a 5.161.108.187 ATORDAusestage
# bash uploadcert.sh da3 e6e0baed-8402-fd5c-7a15-8dd49e7b60d9 5.78.90.106 ATORDAuswstage
# bash uploadcert.sh da4 5ace4a92-63c4-ac72-3ed1-e4485fa0d4a4 5.161.228.187 AnyoneAshLive
# bash uploadcert.sh da5 eb42c498-e7a8-415f-14e9-31e9e71e5707 5.78.94.15 AnyoneHilLive
# bash uploadcert.sh da6 4aa61f61-893a-baf4-541b-870e99ac4839 95.216.32.105 AnyoneHelLive
# bash uploadcert.sh da7 c2adc610-6316-cd9d-c678-cda4b0080b52 176.9.29.53 AnyoneFalLive

## STAGE
bash uploadcert.sh stage-da1-hel-test-1a 4ca2fc3c-8960-6ae7-d931-c0d6030d506b-9101 135.181.231.123 AnyoneHel1aStage
bash uploadcert.sh stage-da2-hel-test-2a 232ea736-591c-4753-9dcc-3e815c4326af-9101 148.251.23.105 AnyoneHel2aStage
bash uploadcert.sh stage-da3-hel-test-3a f3f664d6-7d65-be58-4a2c-4c66e20f1a9f-9101 65.21.12.154 AnyoneHel3aStage

bash uploadcert.sh stage-da2-hel-test-2b 232ea736-591c-4753-9dcc-3e815c4326af-9102 148.251.23.105 AnyoneHel2bStage
bash uploadcert.sh stage-da3-hel-test-3b f3f664d6-7d65-be58-4a2c-4c66e20f1a9f-9102 65.21.12.154 AnyoneHel3bStage
bash uploadcert.sh stage-da2-hel-test-2c 232ea736-591c-4753-9dcc-3e815c4326af-9103 148.251.23.105 AnyoneHel2cStage
bash uploadcert.sh stage-da3-hel-test-3c f3f664d6-7d65-be58-4a2c-4c66e20f1a9f-9103 65.21.12.154 AnyoneHel3cStage

## DEV
# bash uploadcert.sh dev-da1-dmz c8e55509-a756-0aa7-563b-9665aa4915ab 88.99.219.105 AnyoneDmzDev
# bash uploadcert.sh dev-da2-fal c2adc610-6316-cd9d-c678-cda4b0080b52 176.9.29.53 AnyoneFalDev
# bash uploadcert.sh dev-da3-hel 4aa61f61-893a-baf4-541b-870e99ac4839 95.216.32.105 AnyoneHelDev


### -- STEP 3 ---
# mind the phase....
# Move DA folders and script to server, login, run script

## LIVE
# bash uploadsecrets.sh da1 067a42a8-d8fe-8b19-5851-43079e0eabb4
# bash uploadsecrets.sh da2 16be0723-edc1-83c4-6c02-193d96ec308a
# bash uploadsecrets.sh da3 e6e0baed-8402-fd5c-7a15-8dd49e7b60d9
# bash uploadsecrets.sh da4 5ace4a92-63c4-ac72-3ed1-e4485fa0d4a4
# bash uploadsecrets.sh da5 eb42c498-e7a8-415f-14e9-31e9e71e5707
# bash uploadsecrets.sh da6 4aa61f61-893a-baf4-541b-870e99ac4839
# bash uploadsecrets.sh da7 c2adc610-6316-cd9d-c678-cda4b0080b52

## STAGE
# bash uploadsecrets.sh stage-da1-hel-test-1a 4ca2fc3c-8960-6ae7-d931-c0d6030d506b-9101
# bash uploadsecrets.sh stage-da2-hel-test-2a 232ea736-591c-4753-9dcc-3e815c4326af-9101
# bash uploadsecrets.sh stage-da3-hel-test-3a f3f664d6-7d65-be58-4a2c-4c66e20f1a9f-9101

# bash uploadsecrets.sh stage-da2-hel-test-2b 232ea736-591c-4753-9dcc-3e815c4326af-9102
# bash uploadsecrets.sh stage-da3-hel-test-3b f3f664d6-7d65-be58-4a2c-4c66e20f1a9f-9102
# bash uploadsecrets.sh stage-da2-hel-test-2c 232ea736-591c-4753-9dcc-3e815c4326af-9103
# bash uploadsecrets.sh stage-da3-hel-test-3c f3f664d6-7d65-be58-4a2c-4c66e20f1a9f-9103

## DEV
# bash uploadsecrets.sh dev-da1-dmz c8e55509-a756-0aa7-563b-9665aa4915ab
# bash uploadsecrets.sh dev-da2-fal c2adc610-6316-cd9d-c678-cda4b0080b52
# bash uploadsecrets.sh dev-da3-hel 4aa61f61-893a-baf4-541b-870e99ac4839
