


#Using bazar to test profiles


## Upload profile src
Upload old profile src
- `irys upload /path/to/profile000.lua
  -t arweave -w /path/to/wallet.json`
Upload new profile src
  `irys upload /path/to/profile000.lua
  -t arweave -w /path/to/wallet.json`


## Create Profile Process
Create old version of profile registry using aos cli
 `aos test-registry --module u1Ju_X8jiuq4rX9Nh-ZGRQuYQZgV2MKLMT3CZsykk54`

## Update bazar config
Update profilesrc and profileRegistry in bazar config.ts

## Create Profile in bazar
Run npm install, npm start
Make sure arconnect is unlocked / have your password ready
Create a profile in bazar



