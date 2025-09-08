#!/usr/bin/env python3
"""
Enhanced MCP Performance Monitor for Splunk - FIXED VERSION
Monitors system resources and MCP application performance
"""

import psutil
import requests
import json
import time
import logging
import os
import sys
from datetime import datetime
from collections import namedtuple

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Create a named tuple for memory info fallback
MemoryInfo = namedtuple('MemoryInfo', ['rss', 'vms'])

class MCPPerformanceMonitor:
    def __init__(self, mcp_host="localhost", mcp_port=8008, log_file="/opt/splunk/var/log/mcp_performance.log"):
        self.mcp_host = mcp_host
        self.mcp_port = mcp_port
        self.log_file = log_file
        self.mcp_sse_url = f"http://{mcp_host}:{mcp_port}/sse"
        
        # Ensure log directory exists
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
        print(f"Log directory created/verified: {os.path.dirname(log_file)}")
    
    def get_system_metrics(self):
        """Collect comprehensive system metrics"""
        try:
            # CPU metrics
            cpu_times = psutil.cpu_times()
            cpu_percent = psutil.cpu_percent(interval=1, percpu=False)
            cpu_count = psutil.cpu_count()
            
            # Memory metrics
            memory = psutil.virtual_memory()
            swap = psutil.swap_memory()
            
            # Disk metrics
            disk_usage = psutil.disk_usage('/')
            disk_io = psutil.disk_io_counters()
            
            # Network metrics
            network_io = psutil.net_io_counters()
            
            # Load average (Linux specific)
            try:
                load_avg = os.getloadavg()
            except (OSError, AttributeError):
                load_avg = [0, 0, 0]
            
            return {
                "cpu": {
                    "percent": cpu_percent,
                    "count": cpu_count,
                    "user": cpu_times.user,
                    "system": cpu_times.system,
                    "idle": cpu_times.idle,
                    "iowait": getattr(cpu_times, 'iowait', 0)
                },
                "memory": {
                    "total_gb": round(memory.total / (1024**3), 2),
                    "available_gb": round(memory.available / (1024**3), 2),
                    "used_gb": round(memory.used / (1024**3), 2),
                    "percent": memory.percent,
                    "swap_total_gb": round(swap.total / (1024**3), 2),
                    "swap_used_gb": round(swap.used / (1024**3), 2),
                    "swap_percent": swap.percent
                },
                "disk": {
                    "total_gb": round(disk_usage.total / (1024**3), 2),
                    "used_gb": round(disk_usage.used / (1024**3), 2),
                    "free_gb": round(disk_usage.free / (1024**3), 2),
                    "percent": round((disk_usage.used / disk_usage.total) * 100, 2),
                    "read_bytes": disk_io.read_bytes if disk_io else 0,
                    "write_bytes": disk_io.write_bytes if disk_io else 0
                },
                "network": {
                    "bytes_sent": network_io.bytes_sent if network_io else 0,
                    "bytes_recv": network_io.bytes_recv if network_io else 0,
                    "packets_sent": network_io.packets_sent if network_io else 0,
                    "packets_recv": network_io.packets_recv if network_io else 0
                },
                "load_average": {
                    "1min": load_avg[0],
                    "5min": load_avg[1], 
                    "15min": load_avg[2]
                }
            }
        except Exception as e:
            logger.error(f"Error collecting system metrics: {e}")
            return {}
    
    def get_mcp_process_metrics(self):
        """Get MCP-specific process information - FIXED VERSION"""
        mcp_processes = []
        total_cpu = 0
        total_memory = 0
        total_rss = 0
        
        try:
            for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent', 'memory_info', 'status', 'cmdline', 'create_time']):
                try:
                    cmdline = proc.info.get('cmdline', [])
                    # Look for MCP server processes
                    if any('server.py' in str(cmd) for cmd in cmdline) or any('mcp' in str(cmd).lower() for cmd in cmdline):
                        # Get memory info safely
                        mem_info = proc.info.get('memory_info')
                        if mem_info is None:
                            # Create fallback memory info
                            mem_info = MemoryInfo(rss=0, vms=0)
                        
                        proc_data = {
                            'pid': proc.info['pid'],
                            'name': proc.info['name'],
                            'cpu_percent': proc.info['cpu_percent'] or 0,
                            'memory_percent': proc.info['memory_percent'] or 0,
                            'memory_rss_mb': round(mem_info.rss / (1024*1024), 2) if mem_info.rss else 0,
                            'memory_vms_mb': round(mem_info.vms / (1024*1024), 2) if mem_info.vms else 0,
                            'status': proc.info['status'],
                            'uptime_hours': round((time.time() - proc.info['create_time']) / 3600, 2),
                            'cmdline': ' '.join(cmdline[:3])  # First 3 command line args for identification
                        }
                        
                        mcp_processes.append(proc_data)
                        total_cpu += proc_data['cpu_percent']
                        total_memory += proc_data['memory_percent']
                        total_rss += proc_data['memory_rss_mb']
                        
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    continue
                except Exception as e:
                    logger.debug(f"Error processing individual process: {e}")
                    continue
                    
        except Exception as e:
            logger.error(f"Error getting MCP process metrics: {e}")
        
        return {
            "process_count": len(mcp_processes),
            "processes": mcp_processes,
            "total_cpu_percent": round(total_cpu, 2),
            "total_memory_percent": round(total_memory, 2),
            "total_memory_rss_mb": round(total_rss, 2)
        }
    
    def check_mcp_sse_health(self):
        """Check MCP SSE endpoint health and performance - Enhanced for SSE"""
        health_data = {
            "is_healthy": False,
            "response_time_ms": 0,
            "status_code": 0,
            "error": None,
            "endpoint": self.mcp_sse_url,
            "method": "unknown"
        }
        
        # Method 1: Try SSE-specific request
        try:
            start_time = time.time()
            headers = {
                'Accept': 'text/event-stream',
                'Cache-Control': 'no-cache',
                'Connection': 'keep-alive',
                'User-Agent': 'MCP-Monitor/1.0'
            }
            
            response = requests.get(
                self.mcp_sse_url, 
                timeout=8,
                allow_redirects=True,
                headers=headers,
                stream=True
            )
            response_time = (time.time() - start_time) * 1000
            
            health_data.update({
                "is_healthy": response.status_code in [200, 302],
                "response_time_ms": round(response_time, 2),
                "status_code": response.status_code,
                "content_type": response.headers.get('content-type', 'unknown'),
                "server": response.headers.get('server', 'unknown'),
                "method": "sse_request"
            })
            
            response.close()
            return health_data
            
        except requests.exceptions.Timeout:
            health_data["error"] = "SSE endpoint timeout"
            
        except requests.exceptions.ConnectionError:
            health_data["error"] = "SSE connection refused"
            
        except Exception as e:
            health_data["error"] = f"SSE request failed: {str(e)}"
        
        # Method 2: Try basic HTTP health check on root endpoint
        try:
            start_time = time.time()
            base_url = f"http://{self.mcp_host}:{self.mcp_port}/"
            
            response = requests.get(
                base_url,
                timeout=5,
                headers={'User-Agent': 'MCP-Monitor/1.0'}
            )
            response_time = (time.time() - start_time) * 1000
            
            if response.status_code < 500:  # Any non-server-error response means server is up
                health_data.update({
                    "is_healthy": True,
                    "response_time_ms": round(response_time, 2),
                    "status_code": response.status_code,
                    "method": "http_fallback"
                })
                health_data["error"] = None  # Clear previous error
                return health_data
                
        except Exception as e:
            health_data["error"] = f"HTTP fallback failed: {str(e)}"
        
        # Method 3: Basic TCP connectivity test
        try:
            import socket
            start_time = time.time()
            
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(3)
            result = sock.connect_ex((self.mcp_host, self.mcp_port))
            sock.close()
            
            response_time = (time.time() - start_time) * 1000
            
            if result == 0:  # Connection successful
                health_data.update({
                    "is_healthy": True,
                    "response_time_ms": round(response_time, 2),
                    "status_code": 200,  # Assume healthy if port is open
                    "method": "tcp_check"
                })
                health_data["error"] = "TCP connect OK, HTTP failed"
                return health_data
                
        except Exception as e:
            health_data["error"] = f"All connection methods failed: {str(e)}"
        
        # If all methods fail
        health_data["method"] = "all_failed"
        return health_data
    
    def collect_all_metrics(self):
        """Collect all metrics and return structured data"""
        timestamp = datetime.now()
        
        metrics = {
            "timestamp": timestamp.isoformat(),
            "epoch": int(timestamp.timestamp()),
            "host": os.uname().nodename,
            "monitor_type": "mcp_performance",
            "system": self.get_system_metrics(),
            "mcp_processes": self.get_mcp_process_metrics(),
            "mcp_health": self.check_mcp_sse_health()
        }
        
        return metrics
    
    def log_metrics_to_splunk(self, metrics):
        """Log metrics in Splunk-friendly JSON format"""
        try:
            with open(self.log_file, 'a') as f:
                f.write(json.dumps(metrics) + '\n')
        except Exception as e:
            logger.error(f"Error writing metrics to log file {self.log_file}: {e}")
            print(f"Failed to write to log file: {e}")
    
    def run_single_collection(self):
        """Run a single metrics collection cycle"""
        try:
            metrics = self.collect_all_metrics()
            self.log_metrics_to_splunk(metrics)
            
            # Print summary to console
            system = metrics.get('system', {})
            mcp_health = metrics.get('mcp_health', {})
            mcp_proc = metrics.get('mcp_processes', {})
            
            timestamp = datetime.now().strftime("%H:%M:%S")
            cpu = system.get('cpu', {}).get('percent', 0)
            memory = system.get('memory', {}).get('percent', 0)
            health_status = "✅" if mcp_health.get('is_healthy') else "❌"
            proc_count = mcp_proc.get('process_count', 0)
            response_time = mcp_health.get('response_time_ms', 0)
            error_msg = mcp_health.get('error', '')
            
            print(f"[{timestamp}] CPU: {cpu:5.1f}% | Memory: {memory:5.1f}% | "
                  f"MCP: {health_status} ({response_time}ms) | Processes: {proc_count}")
            
            if error_msg:
                print(f"           MCP Error: {error_msg}")
            
            if proc_count > 0:
                print(f"           MCP Processes found:")
                for proc in mcp_proc.get('processes', []):
                    print(f"             PID {proc['pid']}: {proc['name']} - CPU: {proc['cpu_percent']}% Memory: {proc['memory_rss_mb']}MB")
            
            return metrics
            
        except Exception as e:
            logger.error(f"Error during metrics collection: {e}")
            print(f"Collection error: {e}")
            return None

def test_dependencies():
    """Test if all required dependencies are available"""
    try:
        import psutil
        import requests
        import json
        print("✅ All required Python modules are available")
        
        # Test psutil functions
        psutil.cpu_percent()
        psutil.virtual_memory()
        print("✅ psutil functions working correctly")
        
        return True
    except ImportError as e:
        print(f"❌ Missing dependency: {e}")
        return False
    except Exception as e:
        print(f"❌ Error testing dependencies: {e}")
        return False

if __name__ == "__main__":
    print("🔧 MCP Performance Monitor - Fixed Version")
    print("=" * 50)
    
    # Test dependencies first
    if not test_dependencies():
        print("Please install missing dependencies and try again")
        sys.exit(1)
    
    # Initialize monitor
    monitor = MCPPerformanceMonitor()
    
    print(f"Starting MCP Performance Monitor...")
    print(f"Logging to: {monitor.log_file}")
    print(f"Monitoring MCP SSE endpoint: {monitor.mcp_sse_url}")
    print(f"Press Ctrl+C to stop monitoring\n")
    
    try:
        while True:
            monitor.run_single_collection()
            time.sleep(30)  # Collect metrics every 30 seconds
    except KeyboardInterrupt:
        print("\n✅ Monitoring stopped by user")
    except Exception as e:
        logger.error(f"Monitoring error: {e}")
        print(f"❌ Monitoring error: {e}")