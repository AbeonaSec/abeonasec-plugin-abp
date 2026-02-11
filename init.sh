#!/bin/bash

# init.sh
# script to intialize and run the 
# Anomolous Behavior Profiling plugin
# written by Aaron Krapes
# Feb 10, 2026

# model handling logic
# maybe copy from this folder to a specified one?
# or are we restarting tritonserver?

# check if script is being run with sudo
if [[ $EUID -ne 0 ]]; then
   echo "CRITICAL: This script is not running with root privileges."
   echo "This script requires root privileges in order to create the network bridge for packet sniffing."
   exit 1
fi

# check that podman is installed and other containers are running
echo "Checking health of podman installation..."
if ! dpkg -s podman |& grep "Status: install ok" >/dev/null; then
    apt-get install -y podman podman-compose
fi

# if ! podman ps | grep abeonasec-ui 2>/dev/null; then
#     echo "CRITICAL: Cannot see abeonasec-ui container."
#     echo "This is required in order to find an open port for the Morpheus pipeline."
#     echo "Check the health of the core containers before proceeding with plugin installation."
#     exit 1
# fi

# set port number for HTTP input stage
# loop from 8003 to 8079 and find the first unused port
PORT=8003
MAX=8079
while true; do
    # run ss inside ui container (most stable) to see if any given port is being used
    if ! podman exec abeonasec-ui ss -tulpn | grep -q ":$PORT" >/dev/null; then
        break
    # if it is, iterate the value and repeat
    else
        PORT=$((PORT + 1))
        # if maxxed out at 8079, error and quit
        if [ "$PORT" -gt "$MAX" ]; then
            echo "CRITICAL: All podman pod ports between $START and $MAX are in use."
            echo "Read docs to manually choose a port and run the Morpheus pipeline."
            exit 1
        fi
    fi
done
echo "Using port $PORT for Morpheus pipeline input..."
touch .env
echo "PIPE_IN_PORT=$PORT" >> .env

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
echo "Passing network bridge $BRIDGE into container."
echo "NET_IF=$BRIDGE" >> .env

# call podman compose to start building container
echo "Starting container build."
podman compose up -d --build