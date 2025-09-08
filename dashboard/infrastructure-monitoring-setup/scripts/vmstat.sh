#!/bin/bash
# Simple memory monitoring
MEM_INFO=$(free -m | grep "^Mem:")
MEM_TOTAL=$(echo "$MEM_INFO" | awk '{print $2}')
MEM_USED=$(echo "$MEM_INFO" | awk '{print $3}')
MEM_FREE=$(echo "$MEM_INFO" | awk '{print $4}')


# Get timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Get load averages from /proc/loadavg (more reliable than parsing vmstat)
# Format: load1min load5min load15min running/total lastpid
LOADAVG_DATA=$(cat /proc/loadavg)
LOAD_1MIN=$(echo "$LOADAVG_DATA" | awk '{print $1}')
LOAD_5MIN=$(echo "$LOADAVG_DATA" | awk '{print $2}')
LOAD_15MIN=$(echo "$LOADAVG_DATA" | awk '{print $3}')
RUNNING_PROCESSES=$(echo "$LOADAVG_DATA" | awk '{print $4}' | cut -d'/' -f1)
TOTAL_PROCESSES=$(echo "$LOADAVG_DATA" | awk '{print $4}' | cut -d'/' -f2)

# Get vmstat data for additional metrics
VMSTAT_OUTPUT=$(vmstat 1 1 | tail -1)
if [ -n "$VMSTAT_OUTPUT" ]; then
    # vmstat columns: r b swpd free buff cache si so bi bo in cs us sy id wa st
    PROCS_RUNNING=$(echo "$VMSTAT_OUTPUT" | awk '{print $1}')
    PROCS_BLOCKED=$(echo "$VMSTAT_OUTPUT" | awk '{print $2}')
    MEMORY_USED=$(echo "$VMSTAT_OUTPUT" | awk '{print $4}')
    CPU_USER=$(echo "$VMSTAT_OUTPUT" | awk '{print $13}')
    CPU_SYSTEM=$(echo "$VMSTAT_OUTPUT" | awk '{print $14}')
    CPU_IDLE=$(echo "$VMSTAT_OUTPUT" | awk '{print $15}')
    CPU_WAIT=$(echo "$VMSTAT_OUTPUT" | awk '{print $16}')
else
    PROCS_RUNNING=0
    PROCS_BLOCKED=0
    MEMORY_USED=0
    CPU_USER=0
    CPU_SYSTEM=0
    CPU_IDLE=0
    CPU_WAIT=0
fi

echo "${TIMESTAMP} memTotalMB=$MEM_TOTAL memUsedMB=$MEM_USED memFreeMB=$MEM_FREE loadAvg1min=${LOAD_1MIN} loadAvg5min=${LOAD_5MIN} loadAvg15min=${LOAD_15MIN} running_processes=${RUNNING_PROCESSES} total_processes=${TOTAL_PROCESSES} procs_running=${PROCS_RUNNING} procs_blocked=${PROCS_BLOCKED} cpu_user=${CPU_USER} cpu_system=${CPU_SYSTEM} cpu_idle=${CPU_IDLE} cpu_wait=${CPU_WAIT} event_type=\"system_load\""
