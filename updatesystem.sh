#!/bin/bash

# This script update the operating system software
# It should'nt ask the use any questions, other than sudo password
# It uses command like sudo and apt

# Update the list of locally avalaiible software
sudo apt update

# Update any out of date packages
sudo apt-get -qq upgrade

