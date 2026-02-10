#!/bin/bash

# start.sh
# script to intialize and run the data_run.py script
# adapted to be copied and run inside the plugin-abp container
# written by Aaron Krapes
# Feb 10, 2026

echo "Checking Morpheus pipeline environment variable..."
if [[ -z "$ABP_PIPE_PORT" ]]; then
    echo "CRITICAL: Morpheus pipeline port has not been passed to the container."
    echo "Please set the environment variable ABP_PIPE_PORT."
    kill -s SIGTERM 1 
fi
echo "Found value: $ABP_PIPE_PORT."

echo "Checking if Morpheus pipeline has been started..."
TIMEOUT=60
START_TIME=$SECONDS
until ss -tulpn | grep -q ":${ABP_PIPE_PORT}" 2>/dev/null; do
    if [ $(( SECONDS - START_TIME )) -ge $TIMEOUT ]; then
        echo "CRITICAL: Morpheus pipeline has not started after 60 seconds."
        echo "Ensure pipe_run.py is started and the Morpheus HTTP Server is listening on $ABP_PIPE_PORT."
        kill -s SIGTERM 1
    fi
    sleep 0.5
done
python data_run.py ${ABP_PIPE_PORT}
echo "Setup complete, started sniffing."