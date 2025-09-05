#!/usr/bin/env python3
import time
import psutil
import os
from datetime import datetime

def monitor_performance(duration_minutes=5):
    """Monitor system performance during MCP server operation"""
    
    print(f"Performance monitoring started at: {datetime.now()}")
    print(f"Monitoring duration: {duration_minutes} minutes")
    print("Monitoring MCP Server running on vSphere instance")
    print("-" * 50)
    
    start_time = time.time()
    end_time = start_time + (duration_minutes * 60)
    
    while time.time() < end_time:
        # Get system metrics
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        
        # Get process info if server is running
        python_processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']):
            try:
                if 'python' in proc.info['name'].lower():
                    python_processes.append(proc.info)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] CPU: {cpu_percent:5.1f}% | Memory: {memory.percent:5.1f}% | Python processes: {len(python_processes)}")
        
        time.sleep(5)  # Monitor every 5 seconds
    
    print(f"\nMonitoring completed at: {datetime.now()}")

if __name__ == "__main__":
    monitor_performance()