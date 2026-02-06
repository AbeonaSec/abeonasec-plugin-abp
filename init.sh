#!/bin/bash

# init.sh
# script to intialize and run the 
# Anomolous Behavior Profiling plugin
# written by Aaron Krapes
# Feb 5, 2026

# check that pip is installed
# install python dependencies -- error handling
# set port number for HTTP input stage (check for open?)
# get name of network interface
ip route | grep default | awk '{print $5}' | awk /./
# prompt with LEGAL disclaimer about sniffing on network interface
# ask user if _^^ network interface is the one they would like to run the plugin on
# run python files -- error handling
# NOTE: command line arguments for port number and network interface
# copy model to models folder and remove (?)