#!/bin/bash
# Disk I/O Collection Script for Splunk

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Get iostat data (1 second interval, 1 count)
IOSTAT_OUTPUT=$(iostat -x 1 1 | grep -E '^[a-zA-Z]' | grep -v Device | head -1)

if [ -n "$IOSTAT_OUTPUT" ]; then
    READS_PER_SEC=$(echo "$IOSTAT_OUTPUT" | awk '{print $4}')
    WRITES_PER_SEC=$(echo "$IOSTAT_OUTPUT" | awk '{print $5}')
    READ_KB_PER_SEC=$(echo "$IOSTAT_OUTPUT" | awk '{print $6}')
    WRITE_KB_PER_SEC=$(echo "$IOSTAT_OUTPUT" | awk '{print $7}')
    UTIL_PERCENT=$(echo "$IOSTAT_OUTPUT" | awk '{print $NF}')
    DEVICE=$(echo "$IOSTAT_OUTPUT" | awk '{print $1}')
    
    echo "${TIMESTAMP} device=\"${DEVICE}\" reads_per_sec=${READS_PER_SEC} writes_per_sec=${WRITES_PER_SEC} read_kb_per_sec=${READ_KB_PER_SEC} write_kb_per_sec=${WRITE_KB_PER_SEC} util_percent=${UTIL_PERCENT} event_type=\"disk_io\""
else
    echo "${TIMESTAMP} reads_per_sec=0 writes_per_sec=0 read_kb_per_sec=0 write_kb_per_sec=0 util_percent=0 event_type=\"disk_io\" status=\"no_data\""
fi
