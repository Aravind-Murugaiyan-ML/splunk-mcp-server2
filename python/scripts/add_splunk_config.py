import os
import subprocess
import json
from dotenv import load_dotenv

def load_env_vars():
    """Load environment variables from .env file and validate required keys."""
    load_dotenv()
    
    required_vars = [
        "SPLUNK_HOST",
        "SPLUNK_PORT",
        "SPLUNK_USERNAME",
        "SPLUNK_PASSWORD",
        "SPLUNK_SCHEME",
        "VERIFY_SSL"
    ]
    
    env_vars = {}
    missing_vars = []
    
    for var in required_vars:
        value = os.getenv(var)
        if value is None:
            missing_vars.append(var)
        else:
            env_vars[var] = value
    
    return env_vars, missing_vars

def main():
    """Main function to construct and execute the claude mcp add-json command."""
    # Load environment variables
    env_vars, missing_vars = load_env_vars()
    
    # Check for missing variables
    if missing_vars:
        print("❌ Missing environment variables in .env file:")
        for var in missing_vars:
            print(f"  - {var}")
        if env_vars:
            print("✅ Available environment variables:")
            for var, value in env_vars.items():
                print(f"  - {var}: {value}")
        print("Please add the missing variables to the .env file and try again.")
        return
    
    # Construct the JSON configuration
    config = {
        "command": "python",
        "args": ["server.py", "stdio"],
        "cwd": os.getcwd(),
        "env": {
            "SPLUNK_HOST": env_vars["SPLUNK_HOST"],
            "SPLUNK_PORT": env_vars["SPLUNK_PORT"],
            "SPLUNK_USERNAME": env_vars["SPLUNK_USERNAME"],
            "SPLUNK_PASSWORD": env_vars["SPLUNK_PASSWORD"],
            "SPLUNK_SCHEME": env_vars["SPLUNK_SCHEME"],
            "VERIFY_SSL": env_vars["VERIFY_SSL"]
        }
    }
    
    # Convert config to JSON string
    config_json = json.dumps(config, separators=(",", ":"))
    
    # Construct the claude command
    claude_command = [
        "claude",
        "mcp",
        "add-json",
        "splunk-local",
        config_json
    ]
    
    print("Executing command:")
    print(f"  {' '.join(claude_command)}")
    
    try:
        # Run the command
        result = subprocess.run(
            claude_command,
            check=True,
            text=True,
            capture_output=True
        )
        print("✅ Successfully added splunk-local configuration")
        print(result.stdout)
    except subprocess.CalledProcessError as e:
        print("❌ Failed to execute claude mcp add-json command")
        print(f"Error: {e.stderr}")
    except FileNotFoundError:
        print("❌ 'claude' command not found. Ensure Claude is installed and accessible.")

if __name__ == "__main__":
    main()