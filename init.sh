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
if curl -v telnet://localhost:9092 > /dev/null; then
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

# create docker network to bridge this interface into the container
if ! docker network ls | grep plugin-abp-bridge > /dev/null; then
    echo "Creating bridge with interface $1..."
    # get host subnet and gateway
    SUBNET=$(ip addr | grep -A 3 $1: | grep inet | awk '{print $2}' | awk -F'[./]' '{print $1"."$2"."$3".0/" $5}')
    GATEWAY=$(echo $SUBNET | awk -F'[.]' '{print $1"."$2"."$3".1"}')
    # create network bridge
    BRIDGE=$(docker network create -d macvlan --subnet=$SUBNET --gateway=$GATEWAY -o parent=$1 plugin-abp-bridge)
    BRIDGE=$(basename $BRIDGE .json)
fi
echo $BRIDGE

echo "Adding models and scripts to respective folders..."
ln -sf abp-pcap-xgb /opt/abeonasec/models/abp-pcap-xgb
ln -sf abp-pipe.py /opt/abeonasec/scripts/abp-pipe.py

# call podman compose to start building container
echo "Starting plugin-abp container..."
docker compose up -d

# restart morpheus container
echo "Restarting morpheus container..."
docker restart morpheus
