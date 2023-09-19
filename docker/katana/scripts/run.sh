#!/bin/bash

# run ./wait_and_deploy.sh in background
nohup ./wait_and_deploy.sh &>/dev/null

# run katana
/app/katana
