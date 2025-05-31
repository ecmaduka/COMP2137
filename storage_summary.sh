#!/bin/bash

echo "=== Installed Physical Disks ==="
# Lists disk device names and sizes using lsblk
lsblk -d -o NAME,MODEL,SIZE | grep -v loop

echo ""
echo "=== ext4 Filesystem Usage ==="
# Show size, used, and available space for mounted ext4 partitions
df -hT | awk '$2=="ext4" {print "Mount Point: " $7 ", Size: " $3 ", Used: " $4 ", Available: " $5 ", Use%: " $6}'
