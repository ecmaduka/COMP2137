#!/bin/bash

# Show network interface names and descriptions
sudo lshw -class network | grep -E 'logical name|description'

# Show IPv4 addresses (exclude IPv6)
ip addr show | grep inet | grep -v inet6

# Show the default gateway IP address
ip route | grep default
