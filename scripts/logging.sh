#!/bin/bash

# Color
RED='\033[1;91m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
BLUE='\033[1;94m'
MAGENTA='\033[1;95m'
CYAN='\033[1;96m'
NC='\033[0m'

function red {
    printf "${RED}$@${NC}\n"
}

function green {
    printf "${GREEN}$@${NC}\n"
}

function yellow {
    printf "${YELLOW}$@${NC}\n"
}

function blue {
    printf "${BLUE}$@${NC}\n"
}

function magenta {
    printf "${MAGENTA}$@${NC}\n"
}

function cyan {
    printf "${CYAN}$@${NC}\n"
}

# print a message on stderr, stdout needs to be kept for return values
# $* - messages to print
print() {
    echo >&2 $*
}

# print an ERROR log
# $* - messages to print
log_error() {
    print $(red "$*")
}

# print a WARNING log
# $* - messages to print
log_warning() {
    print $(yellow "$*")
}

# print a SUCCESS log
# $* - messages to print
log_success() {
    print $(green "$*")
}

# print an INFO log
# $* - messages to print
log_info() {
    print $(magenta "$*")
}

# print a command line
# $* - messages to print
log_command() {
    print $(cyan "> $*")
}