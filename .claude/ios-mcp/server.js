import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

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
    name: "screenshot",
    description: "Capture the iOS device screen and receive it back as an image. Use for: seeing what the user sees, debugging UI issues, verifying layout changes.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "pie_chart",
    description: "Render a pie chart showing proportions. Use for: code composition, test coverage breakdown, error distribution, disk usage.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Chart title" },
        slices: { type: "array", items: { type: "object", properties: { label: { type: "string" }, value: { type: "number" } }, required: ["label", "value"] } },
      },
      required: ["slices"],
    },
  },
  {
    name: "timeline",
    description: "Render a vertical timeline of events with SF Symbol icons and colored dots. Use for: git history, deployment history, incident timelines, project milestones.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string" },
        events: { type: "array", items: { type: "object", properties: { date: { type: "string" }, title: { type: "string" }, description: { type: "string" }, icon: { type: "string", description: "SF Symbol name (default: circle.fill)" }, color: { type: "string", description: "blue, green, orange, purple, red, teal, pink, indigo" } }, required: ["date", "title"] } },
      },
      required: ["events"],
    },
  },
  {
    name: "image_carousel",
    description: "Render an image or swipeable image carousel from local file paths or web URLs. Use for: screenshots, before/after comparisons, design references.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string" },
        images: { type: "array", items: { type: "object", properties: { path: { type: "string", description: "Absolute file path on the Mac" }, url: { type: "string", description: "Web URL of the image" }, caption: { type: "string" } } } },
      },
      required: ["images"],
    },
  },
  {
    name: "color_palette",
    description: "Render a color palette with labeled swatches. Use for: app theme colors, design system tokens, proposing UI color changes.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string" },
        colors: { type: "array", items: { type: "object", properties: { hex: { type: "string", description: "Hex color (e.g. '#6050DC')" }, label: { type: "string" } }, required: ["hex"] } },
      },
      required: ["colors"],
    },
  },
  {
    name: "sf_symbols",
    description: "Render a grid of SF Symbols so the user can see and compare them visually. Use for: icon selection, comparing symbol options, showing available icons.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Optional heading" },
        symbols: { type: "array", items: { type: "object", properties: { name: { type: "string", description: "SF Symbol name (e.g. gearshape, slider.horizontal.3)" }, label: { type: "string", description: "Optional display label (defaults to symbol name)" } }, required: ["name"] } },
      },
      required: ["symbols"],
    },
  },
  {
    name: "tree",
    description: "Render a collapsible tree diagram. Use for: folder structures, dependency trees, class hierarchies, architecture overviews. PREFER this over markdown code blocks for any hierarchical structure.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string" },
        root: { type: "object", properties: { label: { type: "string" }, icon: { type: "string", description: "SF Symbol name" }, color: { type: "string" }, children: { type: "array", items: { type: "object" } } }, required: ["label"] },
      },
      required: ["root"],
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
