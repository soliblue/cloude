import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { ListToolsRequestSchema, CallToolRequestSchema } from "@modelcontextprotocol/sdk/types.js";

const server = new Server(
  { name: "cloude-widgets", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

const tools = [
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
