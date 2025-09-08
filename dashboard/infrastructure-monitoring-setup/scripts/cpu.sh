#!/bin/bash
# Get CPU info from top and parse it correctly
CPU_LINE=$(top -bn1 | grep "Cpu(s):" | head -1)

# Extract individual CPU percentages using awk
CPU_USER=$(echo "$CPU_LINE" | awk '{print $2}' | sed 's/%us,//')
CPU_SYS=$(echo "$CPU_LINE" | awk '{print $4}' | sed 's/%sy,//')
CPU_NICE=$(echo "$CPU_LINE" | awk '{print $6}' | sed 's/%ni,//')
CPU_IDLE=$(echo "$CPU_LINE" | awk '{print $8}' | sed 's/%id,//')
CPU_WAIT=$(echo "$CPU_LINE" | awk '{print $10}' | sed 's/%wa,//')

# Clean up any non-numeric characters and provide defaults
CPU_USER=$(echo "$CPU_USER" | tr -d 'a-zA-Z%,' | head -c 10)
CPU_SYS=$(echo "$CPU_SYS" | tr -d 'a-zA-Z%,' | head -c 10)
CPU_NICE=$(echo "$CPU_NICE" | tr -d 'a-zA-Z%,' | head -c 10)
CPU_IDLE=$(echo "$CPU_IDLE" | tr -d 'a-zA-Z%,' | head -c 10)
CPU_WAIT=$(echo "$CPU_WAIT" | tr -d 'a-zA-Z%,' | head -c 10)

# Set defaults if empty
CPU_USER=${CPU_USER:-0}
CPU_SYS=${CPU_SYS:-0}
CPU_NICE=${CPU_NICE:-0}
CPU_IDLE=${CPU_IDLE:-0}
CPU_WAIT=${CPU_WAIT:-0}

echo "CPU_pctUser=$CPU_USER CPU_pctSystem=$CPU_SYS CPU_pctNice=$CPU_NICE CPU_pctIdle=$CPU_IDLE CPU_pctIowait=$CPU_WAIT"
