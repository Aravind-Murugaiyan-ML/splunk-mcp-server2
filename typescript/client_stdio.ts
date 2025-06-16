import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { 
  CallToolResultSchema, 
  ListToolsResultSchema,
  ListResourcesResultSchema 
} from "@modelcontextprotocol/sdk/types.js";

async function main() {
  const transport = new StdioClientTransport({
    command: "ts-node",
    args: ["server.ts"],
    env: { ...process.env, TRANSPORT: "stdio" }
  });
  
  const client = new Client({
    name: "stdio-client",
    version: "1.0.0",
  }, {
    capabilities: {}
  });

  await client.connect(transport);
  console.log("Connected to STDIO server\n");

  // List available tools
  console.log("Available tools:");
  const tools = await client.request(
    { method: "tools/list" },
    ListToolsResultSchema
  );
  tools.tools.forEach((tool) => console.log(`  - ${tool.name}: ${tool.description}`));

  // List available resources
  console.log("\nAvailable resources:");
  const resources = await client.request(
    { method: "resources/list" },
    ListResourcesResultSchema
  );
  resources.resources.forEach((resource) => console.log(`  - ${resource.uri}: ${resource.name}`));

  // Test get_config tool
  console.log("\n1. Testing get_config:");
  const configResult = await client.request(
    {
      method: "tools/call",
      params: {
        name: "get_config",
        arguments: {}
      }
    },
    CallToolResultSchema
  );
  console.log(configResult.content[0].text);

  // Test get_saved_searches tool
  console.log("\n2. Testing get_saved_searches:");
  try {
    const searchesResult = await client.request(
      {
        method: "tools/call",
        params: {
          name: "get_saved_searches",
          arguments: {}
        }
      },
      CallToolResultSchema
    );
    const searchesText = searchesResult.content[0].text as string;
    const searches = JSON.parse(searchesText);
    console.log(`Found ${searches.count} saved searches`);
    if (searches.saved_searches && searches.saved_searches.length > 0) {
      console.log("First 3 saved searches:");
      searches.saved_searches.slice(0, 3).forEach((search: any) => {
        console.log(`  - ${search.name}: ${search.description || 'No description'}`);
      });
    }
  } catch (e: any) {
    console.error("Error:", e.message);
  }

  await client.close();
}

main().catch(console.error);