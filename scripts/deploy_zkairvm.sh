#!/bin/bash

### CONSTANTS
SCRIPT_DIR=`readlink -f $0 | xargs dirname`
ROOT=`readlink -f $SCRIPT_DIR/..`
CACHE_FILE=$ROOT/build/deployed_contracts.txt
STARKNET_ACCOUNTS_FILE=$HOME/.starknet_accounts/starknet_open_zeppelin_accounts.json
PROTOSTAR_TOML_FILE=$ROOT/protostar.toml
NETWORK="alpha-goerli"

### FUNCTIONS
. $SCRIPT_DIR/library.sh # Logging utilities

# print the script usage
usage() {
    print "$0 [-a ACCOUNT_ADDRESS] [-p PROFILE] [-n NETWORK] [-x ADMIN_ADDRESS] [-w WALLET]"
}

# build the protostar project
build() {
    log_info "Building project to generate latest version of the ABI"
    execute protostar build
    if [ $? -ne 0 ]; then exit_error "Problem during build"; fi
}

# Deploy all contracts and log the deployed addresses in the cache file
deploy_all_contracts() {
    [ -f $CACHE_FILE ] && {
        source $CACHE_FILE
        log_info "Found those deployed accounts:"
        cat $CACHE_FILE
        ask "Do you want to deploy missing contracts and initialize them" || return 
    }

    print Profile: $PROFILE
    print Account alias: $ACCOUNT
    print Admin address: $ADMIN_ADDRESS
    print Network: $NETWORK

    ask "Are you OK to deploy with those parameters" || return 

    [ ! -z $PROFILE ] && PROFILE_OPT="--profile $PROFILE"

    # Deploy Minter contract
    if [ -z $ZKAIRVM_ADDRESS ]; then
        owner=$ADMIN_ADDRESS
        log_info "Deploying Zkairvm contract..."
        ZKAIRVM_ADDRESS=`send_transaction "protostar $PROFILE_OPT deploy ./build/Zkairvm.json --inputs $owner --network "$NETWORK"` || exit_error
    fi    

    # Save values in cache file
    (
        echo "ZKAIRVM_ADDRESS=$ZKAIRVM_ADDRESS"
    ) | tee >&2 $CACHE_FILE
}

### ARGUMENT PARSING
while getopts a:p:h option
do
    case "${option}"
    in
        a) ACCOUNT=${OPTARG};;
        x) ADMIN_ADDRESS=${OPTARG};;
        p) PROFILE=${OPTARG};;
        n) NETWORK=${OPTARG};;
        w) WALLET=${OPTARG};;
        h) usage; exit_success;;
        \?) usage; exit_error;;
    esac
done

CONFIG_FILE=$ROOT/scripts/configs/$PROFILE.config
[ -f $CONFIG_FILE ] && source $CONFIG_FILE || exit_error "$CONFIG_FILE file not found"

[ -z $ADMIN_ADDRESS ] && ADMIN_ADDRESS=`get_account_address $ACCOUNT $STARKNET_ACCOUNTS_FILE`
[ -z $ADMIN_ADDRESS ] && exit_error "Unable to determine account address"

[ -z $NETWORK && ! -z $PROFILE ] && NETWORK=`get_network $PROFILE $PROTOSTAR_TOML_FILE`
[ -z $NETWORK ] && exit_error "Unable to determine network"

### PRE_CONDITIONS
check_wallet
check_starknet

### BUSINESS LOGIC

build
deploy_all_contracts

exit_success