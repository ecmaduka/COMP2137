#!/bin/bash

# This is a script to display the current cpu activity level, free memory, and free disk space
 
# Find and display the current cpu activity level
echo -n "System Uptime: "
uptime | awk '{print $1}'

# Find and display system free memory
echo -n "Free Memory: "
free | awk 'NR==2 {print $3}'

# Find and display the system free disk space
echo "System Free Disk: "
df -h | awk '$1 ~ /^\/dev/ {print $1, $4}'



