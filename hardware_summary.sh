#!/bin/bash

# Show the OS name and version
cat /etc/os-release | grep PRETTY_NAME

# Show the first line of CPU model info
cat /proc/cpuinfo | grep 'model name' | head -n 1

# Show total RAM available in a human-readable format
free -h | grep Mem
