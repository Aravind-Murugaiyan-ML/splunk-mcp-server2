# Splunk MCP Server (TypeScript)

A Model Context Protocol (MCP) server that provides seamless integration with Splunk Enterprise, allowing AI assistants to search logs, retrieve indexes, and execute saved searches through a standardized interface.

## Features

- **Full Splunk Integration**: Search, export, and analyze Splunk data
- **Multiple Output Formats**: JSON, Markdown, CSV, and Summary formats
- **Saved Search Support**: List and execute saved searches
- **Index Management**: View index metadata and statistics
- **Resource Access**: Browse saved searches and indexes as MCP resources
- **Dual Transport Support**: Both SSE (Server-Sent Events) and stdio transports
- **Type Safety**: Full TypeScript implementation with comprehensive typing
- **Environment Configuration**: Flexible configuration via `.env` file
- **SPL Query Validation**: Built-in guardrails to detect risky, inefficient, or destructive queries
- **Output Sanitization**: Automatic masking of sensitive data (credit cards, SSNs)

## Prerequisites

- **Node.js 18+** is required
- **Splunk Enterprise** instance with API access
- **Splunk credentials** (username/password or authentication token)

```bash
# Verify Node.js version
node --version  # Should be 18.x or higher
```

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/gesman/splunk-mcp-server.git
cd splunk-mcp-server/typescript
```

### 2. Install Dependencies

```bash
npm install

# Cleanup:
# rm -rf node_modules package-lock.json
# npm cache clean --force
```

### 3. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` with your Splunk configuration:

```env
# Server Configuration
SERVER_NAME=Splunk MCP
SERVER_DESCRIPTION=MCP server for retrieving data from Splunk
HOST=0.0.0.0
PORT=8050

# Transport mode: stdio or sse
TRANSPORT=sse

# Logging
LOG_LEVEL=INFO

# Splunk Configuration
SPLUNK_HOST=your-splunk-host.com
SPLUNK_PORT=8089
SPLUNK_USERNAME=your-username
SPLUNK_PASSWORD=your-password
# Optional: Use token instead of username/password
SPLUNK_TOKEN=
# SSL verification (true/false)
VERIFY_SSL=false

# Search Configuration
# Maximum number of events to return from searches (0 = unlimited)
# Default: 100000, Range: 0-unlimited
SPL_MAX_EVENTS_COUNT=100000

# Risk tolerance level for SPL query validation (0 = reject all risky queries, 100 = allow all)
# Default: 75, Range: 0-100
# Queries with risk scores above this threshold will be rejected
SPL_RISK_TOLERANCE=75

# Safe time range for searches - queries within this range get no time penalty
# Default: 24h, Format: Splunk time modifiers (e.g., 1h, 24h, 7d, 30d, 1mon)
# Queries exceeding this range but not "All time" add +15 to risk score
SPL_SAFE_TIMERANGE=24h

# Enable output sanitization to mask sensitive data (credit cards, SSNs)
# Default: false
# Valid values: true, false (case-sensitive, lowercase only)
# When true, search results will have:
#   - Credit cards masked showing only last 4 digits (e.g., ****-****-****-1234)
#   - SSNs completely masked (e.g., ***-**-****)
SPL_SANITIZE_OUTPUT=false
```

## Running the Server

### TypeScript Mode (ts-node)

#### SSE Mode (Default)

```bash
npm start
```

You should see:
```
Starting Splunk MCP server...
Transport: sse
Splunk client connected
SSE Server running on http://0.0.0.0:8050/sse
```

#### Stdio Mode

Set `TRANSPORT=stdio` in your `.env` file or use environment variable:

```bash
TRANSPORT=stdio npm start
```

### Compiled JavaScript Mode (Node.js)

First, compile the TypeScript files:

```bash
npm run build
```

Then run with Node.js:

```bash
# SSE Mode
npm run start:node

# Stdio Mode
TRANSPORT=stdio node server.js
```

## Testing the Server

### Using the Test Clients

The repository includes test clients for both transport modes:

```bash
# Test SSE transport (ensure server is running first)
npm run sse-client

# Test stdio transport (starts its own server)
npm run stdio-client
```

Expected output:
```
Connected to SSE server

Available tools:
  - search_oneshot: Run a oneshot search query in Splunk
  - search_export: Run an export search query in Splunk
  - get_indexes: Get list of available Splunk indexes
  - get_saved_searches: Get list of saved searches
  - run_saved_search: Run a saved search by name
  - get_config: Get current server configuration
```

## Available Tools

### validate_spl
Validate an SPL query for potential risks and inefficiencies before execution.

**Parameters:**
- `query` (string, required): The SPL query to validate

**Returns:**
- `risk_score`: Risk score from 0-100
- `risk_message`: Detailed explanation of risks found with suggestions
- `risk_tolerance`: Current risk tolerance setting
- `would_execute`: Whether this query would execute or be blocked
- `execution_note`: Clear message about execution status

**Example:**
```json
{
  "query": "index=* | delete"
}
```

### search_oneshot
Execute a Splunk search and return results immediately.

**Parameters:**
- `query` (string, required): The Splunk search query (e.g., "index=main | head 10")
- `earliest_time` (string, optional): Start time for search (default: "-24h")
- `latest_time` (string, optional): End time for search (default: "now")
- `max_count` (number, optional): Maximum results to return (default: 100 or SPL_MAX_EVENTS_COUNT)
- `output_format` (string, optional): Format for results - json, markdown/md, csv, or summary (default: "json")
- `risk_tolerance` (number, optional): Override risk tolerance level (default: SPL_RISK_TOLERANCE from .env)
- `sanitize_output` (boolean, optional): Override output sanitization (default: SPL_SANITIZE_OUTPUT from .env)

**Example:**
```json
{
  "query": "index=_internal | head 10",
  "earliest_time": "-1h",
  "output_format": "markdown",
  "risk_tolerance": 80,
  "sanitize_output": true
}
```

### search_export
Stream search results from Splunk (better for large result sets).

**Parameters:** Same as `search_oneshot`

### get_indexes
Retrieve list of all Splunk indexes with metadata.

**Returns:** Index information including name, event count, size, time range, and retention settings.

### get_saved_searches
List all saved searches available in Splunk.

**Returns:** Saved search names, queries, descriptions, schedules, and configured actions.

### run_saved_search
Execute a saved search by name.

**Parameters:**
- `search_name` (string, required): Name of the saved search
- `trigger_actions` (boolean, optional): Whether to trigger configured actions (default: false)

### get_config
Get current server configuration (excludes sensitive information).

## SPL Query Validation (Guardrails)

The server includes built-in validation to detect potentially risky or inefficient SPL queries before execution. This helps prevent:

- **Destructive Operations**: Commands like `delete` that permanently remove data
- **Performance Issues**: Unbounded searches, expensive commands, or missing time ranges
- **Resource Consumption**: Queries that could overwhelm system resources
- **Security Risks**: External script execution or unsafe operations

### Risk Scoring

Each query is analyzed and assigned a risk score from 0-100:
- **0-30**: Low risk - Query is generally safe
- **31-60**: Medium risk - Query may have performance implications
- **61-100**: High risk - Query could be destructive or severely impact performance

### Common Risk Factors

1. **Destructive Commands** (High Risk):
   - `delete` command (+80 points)
   - `collect` with `override=true` (+25 points)
   - `outputlookup` with `override=true` (+20 points)

2. **Time Range Issues**:
   - All-time searches or missing time constraints (+50 points)
   - Time ranges exceeding safe threshold (+20 points)

3. **Performance Concerns**:
   - `index=*` without constraints (+35 points)
   - Expensive commands like `transaction`, `map`, `join` (+20 points each)
   - Missing index specification (+20 points)
   - Subsearches without limits (+20 points)

4. **Security Risks**:
   - External script execution (+40 points)

### Configuration

Configure validation behavior in your `.env` file:
- `SPL_RISK_TOLERANCE`: Set threshold for blocking queries (default: 75)
- `SPL_SAFE_TIMERANGE`: Define safe time range (default: 24h)
- `SPL_SANITIZE_OUTPUT`: Enable/disable output sanitization

### Testing Validation

Use the included test script to validate queries interactively:

```bash
# First compile TypeScript
npm run build

# Run the validation test
node validate_spl_test.js
```

## Resources

The server provides two MCP resources:

- **splunk://saved-searches** - Browse all saved searches
- **splunk://indexes** - View index information and statistics

## Client Configuration

### Claude Desktop

#### SSE Mode Configuration

Add to your Claude Desktop configuration file:
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`
- Linux: `~/.config/claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "splunk-mcp-server": {
      "url": "http://localhost:8050/sse"
    }
  }
}
```

#### Stdio Mode Configuration

**Option 1: Using ts-node (Development)**
```json
{
  "mcpServers": {
    "splunk-mcp-server": {
      "command": "npx",
      "args": ["ts-node", "/path/to/splunk-mcp-server/typescript/server.ts"],
      "env": {
        "TRANSPORT": "stdio"
      }
    }
  }
}
```

**Option 2: Using Node.js (Production)**
```json
{
  "mcpServers": {
    "splunk-mcp-server": {
      "command": "node",
      "args": ["/path/to/splunk-mcp-server/typescript/server.js"],
      "env": {
        "TRANSPORT": "stdio"
      }
    }
  }
}
```

**Option 3: Using npx (Package Installation)**
```json
{
  "mcpServers": {
    "splunk-mcp-server": {
      "command": "npx",
      "args": ["-y", "splunk-mcp-server"],
      "env": {
        "TRANSPORT": "stdio"
      }
    }
  }
}
```

### VS Code

Configure the Splunk MCP server in VS Code by adding it to your settings:

1. Open VS Code Settings (Cmd/Ctrl + ,)
2. Search for "mcp"
3. Click "Edit in settings.json"
   (Windows: /C:/Users/USER_NAME/AppData/Roaming/Code/User/settings.json)
4. Add the following configuration:



#### SSE Mode Configuration

```json
{
  "mcp": {
    "servers": {
      "splunk-mcp-server": {
        "type": "sse",
        "url": "http://localhost:8050/sse"
      }
    }
  }
}
```

**Note:** You must start the server manually before using it in VS Code:
```bash
cd /path/to/splunk-mcp-server/typescript
npm start
```

#### Stdio Mode Configuration

**Option 1: Using npx with ts-node (Development)**
```json
{
  "mcp": {
    "servers": {
      "splunk-mcp-server": {
        "type": "stdio",
        "command": "npx",
        "args": ["ts-node", "/path/to/splunk-mcp-server/typescript/server.ts"],
        "env": {
          "TRANSPORT": "stdio",
          "SPLUNK_HOST": "your-splunk-host.com",
          "SPLUNK_PORT": "8089",
          "SPLUNK_USERNAME": "your-username",
          "SPLUNK_PASSWORD": "your-password",
          "VERIFY_SSL": "false"
        }
      }
    }
  }
}
```

**Option 2: Using node (Production)**
```json
{
  "mcp": {
    "servers": {
      "splunk-mcp-server": {
        "type": "stdio",
        "command": "node",
        "args": ["/path/to/splunk-mcp-server/typescript/server.js"],
        "env": {
          "TRANSPORT": "stdio",
          "SPLUNK_HOST": "your-splunk-host.com",
          "SPLUNK_PORT": "8089",
          "SPLUNK_USERNAME": "your-username",
          "SPLUNK_PASSWORD": "your-password",
          "VERIFY_SSL": "false"
        }
      }
    }
  }
}
```

**Option 3: Using npx from npm registry**
```json
{
  "mcp": {
    "servers": {
      "splunk-mcp-server": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "splunk-mcp-server"],
        "env": {
          "TRANSPORT": "stdio",
          "SPLUNK_HOST": "your-splunk-host.com",
          "SPLUNK_PORT": "8089",
          "SPLUNK_USERNAME": "your-username",
          "SPLUNK_PASSWORD": "your-password",
          "VERIFY_SSL": "false"
        }
      }
    }
  }
}
```

**Option 4: With .env file (Recommended)**

If you have configured a `.env` file in your project directory:
```json
{
  "mcp": {
    "servers": {
      "splunk-mcp-server": {
        "type": "stdio",
        "command": "npx",
        "args": ["ts-node", "server.ts"],
        "cwd": "/path/to/splunk-mcp-server/typescript",
        "env": {
          "TRANSPORT": "stdio"
        }
      }
    }
  }
}
```

#### Remote debugging (VS Code on Windows -> Connected to remote Linux server)
Edit: ~/.vscode-server/data/Machine/settings.json
```json
// With 'node':
{
    ...
    "mcp": {
        "servers": {
            "splunk-mcp-server": {
                "type": "stdio",
                "command": "node",
                "args": ["/path/to/splunk-mcp-server/typescript/server.js"],
                "env": {
                    "TRANSPORT": "stdio",
                    "SPLUNK_HOST": "splunk_host",
                    "SPLUNK_PORT": "8089",
                    "SPLUNK_USERNAME": "admin",
                    "SPLUNK_PASSWORD": "changeme",
                    "VERIFY_SSL": "false"
                }
            }
        }
    }
}

// With 'npx':
{
    ...
    "mcp": {
        "servers": {
            "splunk-mcp-server": {
                "type": "stdio",
                "command": "npx",
                "args": ["/path/to/splunk-mcp-server/typescript"],
                "env": {
                    "TRANSPORT": "stdio",
                    "SPLUNK_HOST": "splunk_host",
                    "SPLUNK_PORT": "8089",
                    "SPLUNK_USERNAME": "admin",
                    "SPLUNK_PASSWORD": "changeme",
                    "VERIFY_SSL": "false"
                }
            }
        }
    }
}

```


#### Verifying the Configuration

After adding the configuration:
1. Restart VS Code
2. Open a new chat in GitHub Copilot
3. Type `@#` to see available MCP servers
4. You should see `splunk-mcp-server` in the list

### Claude Code

#### SSE Mode

First start the server:
```bash
cd /path/to/splunk-mcp-server/typescript
npm start
```

Then add to Claude Code:
```bash
claude mcp add splunk-mcp-server --transport sse --scope project http://localhost:8050/sse
```

#### Stdio Mode

**Option 1: Using ts-node**
```bash
cd /path/to/splunk-mcp-server/typescript
claude mcp add splunk-mcp-server -e TRANSPORT=stdio --scope project -- npx ts-node server.ts
```

**Option 2: Using Node.js**
```bash
cd /path/to/splunk-mcp-server/typescript
# First compile the TypeScript files
npm run build
# Then add to Claude Code
claude mcp add splunk-mcp-server -e TRANSPORT=stdio --scope project -- node server.js
```

To remove:
```bash
claude mcp remove splunk-mcp-server --scope project
```

## Docker Deployment

```bash
# Build the image
sudo docker build -t splunk-mcp-ts .

# Run the container
sudo docker run --env-file .env -p 8050:8050 splunk-mcp-ts
```

## Output Formats

### JSON (default)
Returns raw event data as JSON objects.

### Markdown
Formats results as a markdown table, ideal for documentation.

### CSV
Comma-separated values format for spreadsheet import.

### Summary
Natural language summary including field analysis and statistics.

## Troubleshooting

### Connection Issues

1. **"Splunk client not initialized"**
   - Verify SPLUNK_HOST and credentials in `.env`
   - Ensure Splunk instance is accessible
   - Check firewall rules for Splunk management port (8089)

2. **Authentication Failed**
   - Verify username/password or token
   - Ensure user has appropriate Splunk permissions
   - Try using token authentication instead of basic auth

3. **SSL Certificate Errors**
   - Set `VERIFY_SSL=false` for self-signed certificates
   - Or add proper CA certificates to your system

### Server Issues

1. **Port Already in Use**
   ```bash
   lsof -i :8050  # Check what's using the port
   ```

2. **TypeScript Compilation Errors**
   ```bash
   npx tsc --noEmit  # Check for type errors
   ```

## Architecture

```
typescript/
├── server.ts              # Main MCP server implementation
├── splunkClient.ts        # Splunk REST API client
├── helpers.ts             # Formatting utilities
├── guardrails.ts          # SPL query validation and sanitization
├── splRiskRules.ts        # Configurable risk rules for validation
├── validate_spl_test.ts   # Interactive validation testing tool
├── client_sse.ts          # SSE test client
├── client_stdio.ts        # Stdio test client
├── package.json           # Node.js dependencies
├── tsconfig.json          # TypeScript configuration
├── .env.example           # Environment template
└── Dockerfile             # Container deployment
```

## Development

### Adding New Tools

1. Add the tool definition in `server.ts`:
```typescript
server.tool(
  "tool_name",
  "Tool description",
  {
    param1: z.string().describe("Parameter description"),
    param2: z.number().optional().describe("Optional parameter")
  },
  async ({ param1, param2 }) => {
    // Implementation
    return {
      content: [{
        type: "text",
        text: JSON.stringify(result)
      }]
    };
  }
);
```

2. Add corresponding method in `splunkClient.ts` if needed

### Running Tests

```bash
# Type checking
npx tsc --noEmit

# Test with example clients
npm run sse-client
npm run stdio-client

# Test SPL validation interactively
node validate_spl_test.js
```

## License

This project is licensed under the MIT License.

## Resources

- [MCP Documentation](https://modelcontextprotocol.io/docs)
- [Splunk REST API Reference](https://docs.splunk.com/Documentation/Splunk/latest/RESTREF/RESTprolog)
- [TypeScript MCP SDK](https://github.com/modelcontextprotocol/typescript-sdk)