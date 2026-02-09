#!/bin/bash

# init.sh
# script to intialize and run the 
# Anomolous Behavior Profiling plugin
# written by Aaron Krapes
# Feb 7, 2026

# model handling logic
# maybe copy from this folder to a specified one?
# or are we restarting tritonserver?

# set port number for HTTP input stage
# loop from 8003 to 8079 and find the first unused port
PORT=8003
MAX=8079
while true; do
    # run ss inside ui container (most stable) to see if any given port is being used
    if ! podman exec abeonasec-ui ss -tulpn | grep -q ":$PORT" 2>/dev/null; then
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
-----------------------------------------------------------------------
THIS PROGRAM SNIFFS PACKETS FROM A SPECIFIED NETWORK INTERFACE

DO NOT EVER RUN THIS PROGRAM GIVEN AN INTERFACE THAT HAS ACCESS TO A 
NETWORK WHICH YOU DO NOT OWN OR HAVE LEGAL PERMISSION TO ADMINISTRATE
-----------------------------------------------------------------------
"

# prompt the user to acknowledge
read -p "Type 'accept' to acknowledge and proceed with the installation: " INPUT
if [ "$INPUT" != "accept" ]; then
    echo "You must acknowledge these terms."
    exit 1
fi

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

# create podman network to bridge this interface into the container
BRIDGE=plugin-abp-bridge
podman network create -d macvlan -o parent=$NET_IF plugin-abp-bridge
echo "NET_IF=$BRIDGE" >> .env

# call podman compose to start building container
podman compose up -d