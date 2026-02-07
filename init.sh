#!/bin/bash

# init.sh
# script to intialize and run the 
# Anomolous Behavior Profiling plugin
# written by Aaron Krapes
# Feb 7, 2026

# model handling logic
# maybe copy from this folder to a specified one?
# or are we restarting tritonserver?

# check that pip is installed
# if not, install
if ! command -v pip &> /dev/null; then
    apt-get update
    apt-get install -y python3-pip
    # if apt-get failed exit and error
    if [ $? -ne 0 ]; then
        echo "CRITICAL: Failed to install pip using apt-get."
        echo "Recommend installing manually and re-running this script." 
        exit 1
    fi
fi

# install python dependencies
# NOTE: add error handling
pip install -r requirements.txt
apt-get install -y libpcap-dev

# set port number for HTTP input stage
# loop from 8003 to 8079 and find the first unused port
PORT=8003
MAX=8079
while true; do
    # netcat the port to see if it is being used
    if ! nc -z localhost "$PORT" 2>/dev/null; then
        break
    # if it is, iterate the value and repeat
    else
        PORT=$((PORT + 1))
        # if maxxed out at 8079, error and quit
        if [ "$PORT" -gt "$MAX" ]; then
            echo "CRITICAL: All localhost ports between $START and $MAX are in use."
            echo "Read docs to manually choose a port and run the Morpheus pipeline."
            exit 1
        fi
    fi
done
echo "Using port $PORT for Morpheus pipeline input..."

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

# run python files
# NOTE: add error handling
chmod +x data_run.py pipe_run.py
./pipe_run.py $PORT

# make sure http server input stage is running before starting the sniffing code
# setting timeout of 60 seconds for now (can adjust later if problematic)
TIMEOUT=60
START_TIME=$SECONDS
until nc -z localhost "$PORT" 2>/dev/null; do
    if [ $(( SECONDS - START_TIME )) -ge $TIMEOUT ]; then
        echo "CRITICAL: Morpheus pipeline has not started after 60 seconds."
        echo "Ensure pipe_run.py is started and the Morpheus HTTP Server is listening on $PORT."
        exit 1
    fi
    sleep 0.5
done

./data_run.py $PORT $NET_IF
echo "Setup complete!!"
echo "Started sniffing on $NET_IF. Triple check that this is the correct interface."
