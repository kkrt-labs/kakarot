#!/bin/bash

# convert an ASCII string to hex
# $1 - string value
str_to_hex() {
    str_val=$1
    hex_bytes=$(echo $str_val | xxd -p)
    hex_bytes=0x$(echo $hex_bytes | rev | cut -c3- | rev)
    echo $hex_bytes
}

# convert an ASCII string to hex array
# $1 - string value
str_to_hexs() {
    str_val=$1
    for (( i=0; i<${#str_val}; i++ )); do
        hex=$(str_to_hex ${str_val:$i:1})
        res=$(echo $res $hex)
    done
    echo $res
}

# convert hex to felt
# $1 - hex value
hex_to_felt() {
    hex_upper=`echo ${1//0x/} | tr '[:lower:]' '[:upper:]'`
    echo "obase=10; ibase=16; $hex_upper" | BC_LINE_LENGTH=0 bc
}

# convert felt to hex
# $1 - felt value
felt_to_hex() {
    hex=`echo "obase=16; ibase=10; $1" | BC_LINE_LENGTH=0 bc`
    echo 0x$hex
}

# convert felt to uint256
# $1 - felt value
felt_to_uint256() {
    echo "$1 0"
}

# convert bool to felt
# $1 - felt value
bool_to_felt() {
    if [ $1 = true ] ; then felt=1 ; else felt=0; fi
    echo $felt
}