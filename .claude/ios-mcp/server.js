import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { ListToolsRequestSchema, CallToolRequestSchema } from "@modelcontextprotocol/sdk/types.js";

const server = new Server(
  { name: "cloude-ios", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

const tools = [
  {
    name: "rename",
    description: "Set the conversation name shown in the iOS app header. Use short, memorable names (1-2 words). Call when the topic shifts significantly (~10+ messages in). Naming is automatic on early messages so don't call this at the start of a conversation.",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Conversation name (1-2 words, e.g. 'UI Polish', 'Memory Fix')" },
      },
      required: ["name"],
    },
  },
  {
    name: "symbol",
    description: "Set the SF Symbol icon shown next to the conversation name in the iOS app header. Be specific and creative - pick symbols that uniquely represent the topic (e.g. pill.circle for tool pills, arrow.triangle.branch for git work, waveform for audio). Naming is automatic on early messages so don't call this at the start of a conversation.",
    inputSchema: {
      type: "object",
      properties: {
        symbol: { type: "string", description: "SF Symbol name (e.g. 'paintbrush.pointed', 'cube.transparent', 'waveform')" },
      },
      required: ["symbol"],
    },
  },
  {
    name: "notify",
    description: "Send a push notification to the iOS app. Use for: alerting when a long task completes, important status changes, things the user should know even if they're not looking at the chat.",
    inputSchema: {
      type: "object",
      properties: {
        message: { type: "string", description: "Notification message text" },
      },
      required: ["message"],
    },
  },
  {
    name: "clipboard",
    description: "Copy text to the iOS device clipboard. Use instead of asking the user to copy-paste. Great for: commands to run, URLs, code snippets, any text the user needs outside the chat.",
    inputSchema: {
      type: "object",
      properties: {
        text: { type: "string", description: "Text to copy to clipboard" },
      },
      required: ["text"],
    },
  },
  {
    name: "open",
    description: "Open a URL on the iOS device. Use for: opening links in Safari, deep links to other apps, web pages referenced in conversation.",
    inputSchema: {
      type: "object",
      properties: {
        url: { type: "string", description: "URL to open (e.g. 'https://example.com')" },
      },
      required: ["url"],
    },
  },
  {
    name: "haptic",
    description: "Trigger haptic feedback on the iOS device. Use sparingly for: confirming an action completed, drawing attention to something important.",
    inputSchema: {
      type: "object",
      properties: {
        style: { type: "string", enum: ["light", "medium", "heavy", "rigid", "soft"], description: "Haptic feedback intensity" },
      },
      required: ["style"],
    },
  },
  {
    name: "switch",
    description: "Switch to a different conversation in the iOS app by UUID.",
    inputSchema: {
      type: "object",
      properties: {
        conversationId: { type: "string", description: "UUID of the conversation to switch to" },
      },
      required: ["conversationId"],
    },
  },
  {
    name: "delete",
    description: "Delete the current conversation from the iOS app.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "skip",
    description: "Signal that the heartbeat has nothing useful to do. Use only during heartbeat execution when there are no pending tasks or useful actions to take.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "screenshot",
    description: "Capture the iOS device screen and receive it back as an image. Use for: seeing what the user sees, debugging UI issues, verifying layout changes.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
];

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools }));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  const tool = tools.find((t) => t.name === name);
  if (!tool) return { content: [{ type: "text", text: `Unknown tool: ${name}` }], isError: true };
  return { content: [{ type: "text", text: JSON.stringify(args) }] };
});

const transport = new StdioServerTransport();
await server.connect(transport);
