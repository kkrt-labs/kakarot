#!/bin/bash

# get the account address from the account alias in protostar accounts file
# $1 - account alias
# $2 - starknet account file
get_account_address() {
    account=$1
    starknet_account_file=$2
    grep $account $starknet_account_file -A3 -m1 | sed -n 's@^.*"address":"\(.*\)".*$@\1@p'
}

# get the network from the profile in protostar config file
# $1 - profile
# $2 - protostar toml file
get_network() {
    profile=$1
    protostar_toml_file=$2
    network=$(grep profile.$profile $protostar_toml_file -A3 -m1 | sed -n 's@^.*network="\(.*\)".*$@\1@p')
    echo "network: $network"
    #echo $(get_legacy_network "$network")
}

# get the legacy network name from the network
# $1 - network
get_legacy_network() {
    network=$1
    if [[ "$network" == "testnet" ]]; then
        echo "alpha-goerli"
    elif [[ "$network" == "mainnet" ]]; then
        echo "alpha-mainnet"
    else
        echo $network
    fi
}

# wait for a transaction to be received
# $1 - transaction hash to check
# $2 - network
wait_for_acceptance() {
    tx_hash=$1
    network=$2
    if [[ "$tx_hash" != *"0x"* ]]; then
        tx_hash=$(felt_to_hex "$1")
    fi
    while true 
    do
        tx_status=`starknet tx_status --hash $tx_hash --network $network | sed -n 's@^.*"tx_status": "\(.*\)".*$@\1@p'`
        case "$tx_status"
            in
                NOT_RECEIVED|RECEIVED|PENDING) print -n  $(magenta .);;
                REJECTED) return 1;;
                ACCEPTED_ON_L1|ACCEPTED_ON_L2) return 0; break;;
                *) exit_error "\nUnknown transaction status '$tx_status'";;
            esac
            sleep 2
    done
}

# send a transaction
# $1 - command line to execute
# $2 - network
# return The contract address
send_transaction() {
    transaction=$1
    network=$2
    while true
    do
        execute $transaction || exit_error "Error when sending transaction"
        
        contract_address=`sed -n 's@Contract address: \(.*\)@\1@p' logs.json`
        tx_hash=`sed -n 's@Transaction hash: \(.*\)@\1@p' logs.json`

        wait_for_acceptance $tx_hash $network

        case $? in
            0) log_success "\nTransaction accepted!"; break;;
            1) log_warning "\nTransaction rejected!"; break;;
        esac
    done || exit_error

    echo $contract_address
}