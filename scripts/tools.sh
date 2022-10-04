#!/bin/bash

# print a red error message and exit
# $* - messages to print
exit_error() {
    [ $# -gt 0 ] && log_error $*
    exit 1
}

# print a green success message and exit 
exit_success() {
    log_success "🎉 All done!"
    exit 0
}

# ask a yes/no question to the user
# $1 - question to ask
# Returns 0 (success) if answer is yes, 1 (error) if answer is no
ask() {
    msg=$1
    while true; do
        question=$(magenta "$msg ? [yn] ")
        read -p "$question" yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) print "Please answer yes or no.";;
        esac
    done
}

# print and execute a command
# $* - command line to execute
execute() {
    cmd=$*
    log_command $cmd
    eval 2>&1 $cmd | tee >&2 logs.json
    return ${PIPESTATUS[0]}
}