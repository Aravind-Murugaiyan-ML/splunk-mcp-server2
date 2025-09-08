#!/bin/bash
# File: /opt/splunk/bin/scripts/top.sh
# Purpose: Collect top processes data for Splunk

# Get timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Get top processes data in batch mode
# -b: batch mode, -n1: only one iteration, -o %CPU: sort by CPU usage
TOP_OUTPUT=$(top -b -n1 -o %CPU | grep -v "^$" | tail -n +8 | head -20)

# Counter for process ranking
COUNTER=1

# Parse each process line
echo "$TOP_OUTPUT" | while read -r line; do
    # Skip empty lines and header lines
    [ -z "$line" ] && continue
    echo "$line" | grep -q "PID USER" && continue
    
    # Parse the top output line
    # Typical format: PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ COMMAND
    PID=$(echo "$line" | awk '{print $1}')
    USER=$(echo "$line" | awk '{print $2}')
    PCT_CPU=$(echo "$line" | awk '{print $9}')
    PCT_MEM=$(echo "$line" | awk '{print $10}')
    COMMAND=$(echo "$line" | awk '{print $12}')
    
    # Clean up command name (remove path, keep just the command)
    COMMAND_CLEAN=$(basename "$COMMAND" 2>/dev/null || echo "$COMMAND")
    
    # Skip if CPU percentage is 0 or invalid
    if [ "$PCT_CPU" != "0.0" ] && [ "$PCT_CPU" != "0" ] && [ -n "$PCT_CPU" ]; then
        # Output in Splunk-friendly format with exact field names expected by dashboard
        echo "${TIMESTAMP} rank=${COUNTER} PID=${PID} USER=\"${USER}\" pctCPU=${PCT_CPU} pctMEM=${PCT_MEM} COMMAND=\"${COMMAND_CLEAN}\" full_command=\"${COMMAND}\" event_type=\"process_info\""
        COUNTER=$((COUNTER + 1))
    fi
    
    # Limit to top 15 processes to avoid too much data
    [ $COUNTER -gt 15 ] && break
done
