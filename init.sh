#!/bin/bash

# init.sh
# script to intialize and run the 
# Anomolous Behavior Profiling plugin
# written by Aaron Krapes
# Feb 10, 2026

# check if script is being run with sudo
if [[ $EUID -ne 0 ]]; then
   echo "CRITICAL: This script is not running with root privileges."
   echo "This script requires root privileges in order to create the network bridge for packet sniffing."
   exit 1
fi

# check that podman is installed and other containers are running
echo "Checking health of kafka container..."
curl -v telnet://localhost:9092

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

# prompt the user to acknowledge
read -p "Type 'accept' to acknowledge and proceed with the installation: " INPUT
if [ "$INPUT" != "accept" ]; then
    echo "You must acknowledge these terms."
    exit 1
fi

echo "Displaying network interfaces..."
ip -4 -br addr show

# create podman network to bridge this interface into the container
if ! podman network ls | grep plugin-abp-bridge > /dev/null; then
    # get name of default network interface
    NET_IF=$(ip route | grep default | awk '{print $5}' | awk /./)
    # ask user if _^^ network interface is the one they would like to run the plugin on
    read -p "Is $NET_IF the Network Interface that you would like to sniff on? (y/N): " INPUT
    if [ "$INPUT" == "N" ]; then
        read -p "Input the Network Interface that you would like to sniff on: " NET_IF
    elif [ "$INPUT" != "y" ]; then
        echo "Ensure that you know what interface to be sniffing on"
        exit 1
    fi
    echo "Creating bridge with interface $NET_IF..."
    # get host subnet and gateway
    SUBNET=$(ip addr | grep -A 3 $NET_IF: | grep inet | awk '{print $2}' | awk -F'[./]' '{print $1"."$2"."$3".0/" $5}')
    GATEWAY=$(echo $SUBNET | awk -F'[.]' '{print $1"."$2"."$3".1"}')
    # create network bridge
    BRIDGE=$(podman network create -d macvlan --subnet $SUBNET --gateway $GATEWAY -o parent=$NET_IF plugin-abp-bridge)
    BRIDGE=$(basename $BRIDGE .json)
else
    BRIDGE=plugin-abp-bridge
fi
echo "Network bridge 'plugin-abp-bridge' created."

echo "Adding models and scripts to respective folders..."
ln -s abp-pcap-xgb /opt/abeonasec/models/abp-pcap-xgb
ln -s abp-pipe.py /opt/abeonasec/scripts/abp-pipe.py

# call podman compose to start building container
echo "Starting plugin-abp container..."
podman compose up -d

# restart morpheus container
echo "Restarting morpheus container..."
sudo -u abeonasec podman restart morpheus
