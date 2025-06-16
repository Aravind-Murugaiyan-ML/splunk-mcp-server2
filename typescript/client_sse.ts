import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { SSEClientTransport } from "@modelcontextprotocol/sdk/client/sse.js";
import { 
  CallToolResultSchema, 
  ListToolsResultSchema,
  ListResourcesResultSchema 
} from "@modelcontextprotocol/sdk/types.js";

async function main() {
  const transport = new SSEClientTransport(new URL("http://localhost:8050/sse"));
  const client = new Client({
    name: "sse-client",
    version: "1.0.0",
  }, {
    capabilities: {}
  });

  await client.connect(transport);
  console.log("Connected to SSE server\n");

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

  // Test get_indexes tool
  console.log("\n2. Testing get_indexes:");
  try {
    const indexesResult = await client.request(
      {
        method: "tools/call",
        params: {
          name: "get_indexes",
          arguments: {}
        }
      },
      CallToolResultSchema
    );
    const indexesText = indexesResult.content[0].text as string;
    const indexes = JSON.parse(indexesText);
    console.log(`Found ${indexes.count} indexes`);
    if (indexes.indexes && indexes.indexes.length > 0) {
      console.log("First 3 indexes:");
      indexes.indexes.slice(0, 3).forEach((idx: any) => {
        console.log(`  - ${idx.name}: ${idx.totalEventCount} events, ${idx.currentDBSizeMB} MB`);
      });
    }
  } catch (e: any) {
    console.error("Error:", e.message);
  }

  // Test search_oneshot with a simple query
  console.log("\n3. Testing search_oneshot:");
  try {
    const searchResult = await client.request(
      {
        method: "tools/call",
        params: {
          name: "search_oneshot",
          arguments: {
            query: "index=_internal | head 5",
            earliest_time: "-15m",
            latest_time: "now",
            output_format: "summary"
          }
        }
      },
      CallToolResultSchema
    );
    const searchText = searchResult.content[0].text as string;
    const result = JSON.parse(searchText);
    if (result.content) {
      console.log(result.content);
    } else {
      console.log(JSON.stringify(result, null, 2));
    }
  } catch (e: any) {
    console.error("Error:", e.message);
  }

  await client.close();
}

main().catch(console.error);