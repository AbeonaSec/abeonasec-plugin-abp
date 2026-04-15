#!/bin/bash

# start.sh
# script to intialize and run the data_run.py script
# adapted to be copied and run inside the plugin-abp container
# written by Aaron Krapes
# Mar 11, 2026

# check that interface was provided as command line argument
if [ -z "$1" ]; then
    echo "CRITICAL: Provide interface to be used for network bridge as command line argument."
    exit 1
fi

echo "
LEGAL DISCLAIMER 
--------------------------------------------------------------------------------
THIS PROGRAM SNIFFS PACKETS FROM A SPECIFIED NETWORK INTERFACE

DO NOT EVER RUN THIS PROGRAM GIVEN AN INTERFACE THAT HAS ACCESS TO A 
NETWORK WHICH YOU DO NOT OWN OR HAVE LEGAL PERMISSION TO ADMINISTRATE

THE DEVELOPERS OF ABEONASEC TAKE NO RESPONSIBILITY FOR MISUSE OF THE APPLICATION
--------------------------------------------------------------------------------
"
echo "Checking container network interface."
ip addr | grep -A 3 $1
python3 abp-data.py $1