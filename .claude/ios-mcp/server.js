import fs from "node:fs/promises";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new Server(
  { name: "cloude-ios", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

const tools = (await Promise.all(
  [].map(async (file) =>
    JSON.parse(await fs.readFile(new URL(`tools/${file}.json`, import.meta.url), "utf8")).tools
  )
)).flat();

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools }));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const tool = tools.find((candidate) => candidate.name === request.params.name);
  if (!tool) {
    return { content: [{ type: "text", text: `Unknown tool: ${request.params.name}` }], isError: true };
  }
  return { content: [{ type: "text", text: JSON.stringify(request.params.arguments ?? {}) }] };
});

await server.connect(new StdioServerTransport());
