import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { ListToolsRequestSchema, CallToolRequestSchema } from "@modelcontextprotocol/sdk/types.js";

const server = new Server(
  { name: "cloude-widgets", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

const tools = [
  {
    name: "function_plot",
    description: "Render an interactive 2D function plot with parameter sliders. User drags sliders to change parameters and see the curve update in real-time. Use for: algorithm complexity visualization (O(n) vs O(n log n)), easing curves, signal processing, math explanations.",
    inputSchema: {
      type: "object",
      properties: {
        expression: { type: "string", description: "Math expression using x as variable and optional named parameters (e.g. 'a * sin(b * x + c)')" },
        params: {
          type: "object",
          description: "Named parameters with slider ranges. Each key is a parameter name, value is {value, min, max, step?}",
          additionalProperties: {
            type: "object",
            properties: {
              value: { type: "number" },
              min: { type: "number" },
              max: { type: "number" },
              step: { type: "number" },
            },
            required: ["value", "min", "max"],
          },
        },
        xRange: { type: "array", items: { type: "number" }, minItems: 2, maxItems: 2, description: "X axis range [min, max]" },
        yRange: { type: "array", items: { type: "number" }, minItems: 2, maxItems: 2, description: "Y axis range [min, max]" },
      },
      required: ["expression"],
    },
  },
  {
    name: "interactive_function",
    description: "Render an interactive calculator with sliders for inputs and a live-computed output. Use for: cost estimators (API pricing by token count), performance calculators (throughput vs latency), capacity planning, unit conversions.",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Calculator title" },
        inputs: {
          type: "object",
          description: "Named input parameters with slider ranges. Each key is an input name, value is {value, unit?, min, max, step?}",
          additionalProperties: {
            type: "object",
            properties: {
              value: { type: "number" },
              unit: { type: "string" },
              min: { type: "number" },
              max: { type: "number" },
              step: { type: "number" },
            },
            required: ["value", "min", "max"],
          },
        },
        formula: { type: "string", description: "Math expression using input names as variables" },
        output: {
          type: "object",
          properties: {
            label: { type: "string" },
            unit: { type: "string" },
            format: { type: "string", description: "Printf format string (e.g. '%.1f')" },
          },
          required: ["label"],
        },
      },
      required: ["name", "inputs", "formula", "output"],
    },
  },
  {
    name: "bar_chart",
    description: "Render a bar chart for comparing values. Use for: bundle sizes by module, LOC per file, test counts by status, build times, dependency counts.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Chart title" },
        bars: { type: "array", items: { type: "object", properties: { label: { type: "string" }, value: { type: "number" } }, required: ["label", "value"] } },
        unit: { type: "string", description: "Optional unit label for the values" },
        color: { type: "string", description: "Bar color: blue, green, orange, purple, red, teal, pink (default: blue)" },
      },
      required: ["bars"],
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
    name: "scatter_plot",
    description: "Render a scatter plot for showing relationships and correlations. Use for: file size vs complexity, test duration vs coverage.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string" },
        points: { type: "array", items: { type: "object", properties: { x: { type: "number" }, y: { type: "number" }, label: { type: "string" } }, required: ["x", "y"] } },
        xLabel: { type: "string" },
        yLabel: { type: "string" },
      },
      required: ["points"],
    },
  },
  {
    name: "line_chart",
    description: "Render a data-driven line chart for time series and trends. Use for: build time trends, crash rates, API latency over time.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string" },
        lines: { type: "array", items: { type: "object", properties: { label: { type: "string" }, points: { type: "array", items: { type: "object", properties: { x: { type: "number" }, y: { type: "number" } }, required: ["x", "y"] } } }, required: ["label", "points"] } },
        xLabel: { type: "string" },
        yLabel: { type: "string" },
      },
      required: ["lines"],
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
