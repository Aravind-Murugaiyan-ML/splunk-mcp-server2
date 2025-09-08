#!/bin/bash
# Simple disk monitoring
DATE=$(date '+%m-%d-%Y %H:%M:%S')
DISK_INFO=$(df -m / | tail -1)
USED_MB=$(echo $DISK_INFO | awk '{print $3}')
AVAIL_MB=$(echo $DISK_INFO | awk '{print $4}')

echo "$DATE Mount=\"/\" UsedMB=$USED_MB AvailMB=$AVAIL_MB"
