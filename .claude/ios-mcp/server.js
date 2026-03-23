import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { ListToolsRequestSchema, CallToolRequestSchema } from "@modelcontextprotocol/sdk/types.js";

const server = new Server(
  { name: "cloude-ios", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

const elementProperties = {
  id: { type: "string", description: "Optional stable ID for later update/remove" },
  type: { type: "string", enum: ["rect", "ellipse", "triangle", "text", "path", "arrow"] },
  x: { type: "number", description: "X position (0-1000)" },
  y: { type: "number", description: "Y position (0-1000)" },
  w: { type: "number", description: "Width" },
  h: { type: "number", description: "Height" },
  label: { type: "string", description: "Text content (for text, or label inside shapes)" },
  fill: { type: "string", description: "Fill hex color e.g. #FF6B6B" },
  stroke: { type: "string", description: "Stroke hex color e.g. #FFFFFF" },
  points: { type: "array", items: { type: "array", items: { type: "number" } }, description: "Path points as [[x,y], ...]" },
  closed: { type: "boolean", description: "Close the path?" },
  from: { type: "string", description: "Arrow source element ID" },
  to: { type: "string", description: "Arrow target element ID" },
  z: { type: "integer", description: "Z-order (higher = on top)" },
  fontSize: { type: "number", description: "Font size for text/labels (default: 14 for text, 12 for shape labels, 10 for arrow labels)" },
  strokeWidth: { type: "number", description: "Stroke width in points" },
  strokeStyle: { type: "string", enum: ["solid", "dashed", "dotted"], description: "Stroke line style" },
  opacity: { type: "number", description: "Element opacity 0.0-1.0" },
  groupId: { type: "string", description: "Group ID - elements with the same groupId move/select together" },
  relativeTo: {
    type: "object",
    description: "Position this element relative to another element instead of using absolute x/y",
    properties: {
      id: { type: "string", description: "ID of the reference element" },
      position: { type: "string", enum: ["right", "left", "below", "above"], description: "Where to place relative to the reference" },
      gap: { type: "number", description: "Gap between elements (default: 20)" },
    },
    required: ["id", "position"],
  },
};

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
  {
    name: "whiteboard_open",
    description: "Open the whiteboard canvas on the iOS device. Call this before adding elements if you want the user to see the whiteboard. Adding/updating elements works silently without opening the whiteboard.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "whiteboard_add",
    description: "Add elements to the whiteboard canvas. Coordinate space: 0-1000 virtual units. Center is (500, 500). Returns the IDs of created elements. Use layout param to auto-position elements, or relativeTo on individual elements to position relative to existing elements.",
    inputSchema: {
      type: "object",
      properties: {
        elements: {
          type: "array",
          description: "Elements to place on the canvas",
          items: {
            type: "object",
            properties: elementProperties,
            required: ["type"],
          },
        },
        layout: {
          type: "object",
          description: "Auto-position elements in a layout pattern",
          properties: {
            type: { type: "string", enum: ["grid", "row", "column", "tree", "radial"], description: "Layout algorithm" },
            x: { type: "number", description: "Layout origin X (default: 200)" },
            y: { type: "number", description: "Layout origin Y (default: 200)" },
            spacing: { type: "number", description: "Gap between elements (default: 40)" },
          },
          required: ["type"],
        },
      },
      required: ["elements"],
    },
  },
  {
    name: "whiteboard_remove",
    description: "Remove elements from the whiteboard by their IDs. Also removes any arrows connected to deleted elements.",
    inputSchema: {
      type: "object",
      properties: {
        ids: { type: "array", items: { type: "string" }, description: "Element IDs to delete" },
      },
      required: ["ids"],
    },
  },
  {
    name: "whiteboard_update",
    description: "Update fields on an existing whiteboard element. Only provided fields are changed. Supports all element properties.",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string", description: "Element ID to modify" },
        ...elementProperties,
      },
      required: ["id"],
    },
  },
  {
    name: "whiteboard_clear",
    description: "Clear all elements from the whiteboard.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "whiteboard_snapshot",
    description: "Get the current whiteboard canvas as JSON. Sends the full state (viewport + all elements) back as a user message in the conversation.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "whiteboard_export",
    description: "Render the whiteboard canvas to a JPEG image and send it back as a user message. Use this to visually verify what's on the canvas. Works even if the whiteboard is not visible.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "whiteboard_viewport",
    description: "Set the whiteboard camera position and zoom level. Center of canvas is (0, 0).",
    inputSchema: {
      type: "object",
      properties: {
        x: { type: "number", description: "Camera X offset" },
        y: { type: "number", description: "Camera Y offset" },
        zoom: { type: "number", description: "Zoom level (0.3-5.0, default 1.0)" },
      },
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
