#!/bin/bash

SCRIPT_DIR=`readlink -f $0 | xargs dirname`
source $SCRIPT_DIR/logging.sh
source $SCRIPT_DIR/tools.sh
source $SCRIPT_DIR/converter.sh
source $SCRIPT_DIR/checker.sh
source $SCRIPT_DIR/starknet.sh