#!/bin/bash

# init.sh
# script to intialize and run the 
# Anomolous Behavior Profiling plugin
# written by Aaron Krapes
# Apr 9, 2026

# check if script is being run with sudo
if [[ $EUID -ne 0 ]]; then
   echo "CRITICAL: This script is not running with root privileges."
   echo "This script requires root privileges in order to create the network bridge for packet sniffing."
   exit 1
fi

# check that interface was provided as command line argument
if [ -z "$1" ]; then
    echo "CRITICAL: Provide interface to be used for network bridge as command line argument."
    exit 1
fi

if ! ip -4 -br addr show | grep $1 > /dev/null; then
    echo "CRITICAL: Provided interface name does not exist."
    exit 1
fi

# check that kafka is listening
echo "Checking health of kafka bootstrap server..."
if ! nc -vz localhost 9092 2>&1 | grep "succeeded"; then
    echo "Kafka bootstrap server not detected. Check container health or networking."
    exit 1
fi

# legal disclaimer about sniffing on network interface
echo "
LEGAL DISCLAIMER 
--------------------------------------------------------------------------------
THIS PROGRAM SNIFFS PACKETS FROM A SPECIFIED NETWORK INTERFACE

DO NOT EVER RUN THIS PROGRAM GIVEN AN INTERFACE THAT HAS ACCESS TO A 
NETWORK WHICH YOU DO NOT OWN OR HAVE LEGAL PERMISSION TO ADMINISTRATE

THE DEVELOPERS OF ABEONASEC TAKE NO RESPONSIBILITY FOR MISUSE OF THE APPLICATION
--------------------------------------------------------------------------------
"

echo "Adding models and scripts to respective folders..."
#cp -r abp-pcap-xgb /opt/abeonasec/models/abp-pcap-xgb
#ln abp-pipe.py /opt/abeonasec/scripts/abp-pipe.py

# call podman compose to start building container
echo "Starting plugin-abp..."
docker run --rm -d --cap-add CAP_NET_RAW --network host --name plugin-abp ghcr.io/abeonasec/plugin-abp:latest /usr/src/app/start.sh $2

# start morpheus pipeline
echo "Starting morpheus pipeline..."
docker exec -d morpheus /bin/bash -c '. /opt/conda/etc/profile.d/conda.sh && conda activate morpheus && python3 /scripts/abp-pipe.py > /proc/1/fd/1'
