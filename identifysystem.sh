#!/bin/bash

# This is a script to display the current hostname, IP address, and gateway IP
 
# Find and display the current hostname
echo -n "Hostname: "
hostname

# Find and display IP address
echo -n "Ip Address: "
ip r s default | awk '{print $9}'

# Find and display the gateway IP
echo -n  "Gateway IP: "
ip r s default | awk '{print $3}'
