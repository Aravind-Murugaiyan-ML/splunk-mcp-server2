#!/usr/bin/env node
/**
 * Interactive SPL validation test.
 */

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { SSEClientTransport } from "@modelcontextprotocol/sdk/client/sse.js";
import * as readline from "readline/promises";
import { stdin as input, stdout as output } from "process";

// Colors for output (minimal, matching Interactive SPL Search style)
const GREEN = '\x1b[0;32m';
const RED = '\x1b[0;31m';
const YELLOW = '\x1b[1;33m';
const CYAN = '\x1b[0;36m';
const BOLD = '\x1b[1m';
const RESET = '\x1b[0m';

async function testValidateSpl() {
  const serverUrl = "http://localhost:8050/sse";
  
  const transport = new SSEClientTransport(new URL(serverUrl));
  const client = new Client(
    {
      name: "validate-spl-test",
      version: "1.0.0",
    },
    {
      capabilities: {}
    }
  );

  await client.connect(transport);

  const rl = readline.createInterface({ input, output });

  console.log("🛡️  SPL Query Validation Tool");
  console.log("=".repeat(50));
  console.log("Enter SPL queries to validate. Type /q or /x to exit.");
  console.log("");
  console.log("Features:");
  console.log("  - Risk assessment for SPL queries");
  console.log("  - Use arrow keys to navigate and edit queries");
  console.log("  - Use up/down arrows to access command history");
  console.log("");
  console.log("Example risky queries:");
  console.log("  index=* | delete");
  console.log("  index=main | collect index=summary override=true");
  console.log("  | script python dangerous.py");
  console.log("=".repeat(50));

  try {
    while (true) {
      const query = await rl.question("\nSPL> ");

      // Check for exit commands
      if (['/q', '/x', 'exit', 'quit'].includes(query.toLowerCase())) {
        break;
      }

      if (!query.trim()) {
        continue;
      }

      try {
        // Call validate_spl tool
        const result = await client.callTool({ name: "validate_spl", arguments: { query } });

        // Parse response
        const content = result.content as Array<{ type: string; text: string }>;
        const data = JSON.parse(content[0].text);

        // Display results with appropriate emoji and color
        const riskScore = data.risk_score || 0;
        const riskMessage = data.risk_message || "";

        if (riskScore === 0) {
          console.log(`\n✅ Query is SAFE (Risk Score: ${riskScore}/100)`);
        } else if (riskScore <= 30) {
          console.log(`\n⚠️  LOW RISK (Risk Score: ${riskScore}/100)`);
        } else if (riskScore <= 60) {
          console.log(`\n⚠️  MEDIUM RISK (Risk Score: ${riskScore}/100)`);
        } else {
          console.log(`\n❌ HIGH RISK (Risk Score: ${riskScore}/100)`);
        }

        // Print risk message with proper formatting
        if (riskMessage) {
          console.log(`\n${riskMessage}`);
        }
      } catch (error) {
        console.log(`\n${RED}Error validating query: ${error}${RESET}`);
      }
    }
  } catch (error) {
    // Handle Ctrl+C
  }

  console.log("\nGoodbye!\n");
  
  rl.close();
  await client.close();
}

// Run the test
testValidateSpl().catch(console.error);