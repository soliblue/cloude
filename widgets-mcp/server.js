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
    description: "Render an interactive 2D function plot with parameter sliders. The user can drag sliders to change parameters and see the curve update in real-time.",
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
    name: "fill_in_blank",
    description: "Render a fill-in-the-blank exercise. Blanks appear as tappable underlined slots that reveal answers when tapped.",
    inputSchema: {
      type: "object",
      properties: {
        text: { type: "string", description: "Text with ___ marking each blank position" },
        blanks: { type: "array", items: { type: "string" }, description: "Answers for each blank in order" },
        hint: { type: "string", description: "Optional hint text shown above" },
      },
      required: ["text", "blanks"],
    },
  },
  {
    name: "interactive_function",
    description: "Render an interactive calculator with sliders for inputs and a live-computed output. Like a mini spreadsheet.",
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
    name: "flashcard_deck",
    description: "Render a deck of flashcards. User swipes through cards and taps each to flip between front and back.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Deck title shown at the top" },
        cards: {
          type: "array",
          description: "Array of flashcards, each with front and back text",
          items: {
            type: "object",
            properties: {
              front: { type: "string", description: "Front side text (question/term)" },
              back: { type: "string", description: "Back side text (answer/definition)" },
            },
            required: ["front", "back"],
          },
        },
      },
      required: ["cards"],
    },
  },
  {
    name: "quiz",
    description: "Render a multiple-choice quiz question. User taps an option and gets instant green (correct) or red (incorrect) feedback.",
    inputSchema: {
      type: "object",
      properties: {
        question: { type: "string", description: "The question text" },
        options: { type: "array", items: { type: "string" }, description: "Answer options (2-6 choices)" },
        correct: { type: "integer", description: "Index of the correct answer (0-based)" },
        explanation: { type: "string", description: "Optional explanation shown after answering" },
      },
      required: ["question", "options", "correct"],
    },
  },
  {
    name: "ordering",
    description: "Render an ordering exercise. Items are shown in random order and the user taps them in sequence to arrange them correctly.",
    inputSchema: {
      type: "object",
      properties: {
        instruction: { type: "string", description: "Instruction text (e.g. 'Put these events in chronological order')" },
        items: { type: "array", items: { type: "string" }, description: "Items in their CORRECT order. They will be shuffled for display." },
      },
      required: ["items"],
    },
  },
  {
    name: "matching",
    description: "Render a matching exercise with two columns. User taps one item from the left column then one from the right to create a pair.",
    inputSchema: {
      type: "object",
      properties: {
        instruction: { type: "string", description: "Instruction text (e.g. 'Match each country to its capital')" },
        pairs: {
          type: "array",
          description: "Array of pairs to match. Each pair has a left and right value.",
          items: {
            type: "object",
            properties: {
              left: { type: "string", description: "Left column item" },
              right: { type: "string", description: "Right column item" },
            },
            required: ["left", "right"],
          },
        },
      },
      required: ["pairs"],
    },
  },
  {
    name: "categorization",
    description: "Render a categorization exercise. Items appear at the top and the user taps to sort them into labeled category buckets.",
    inputSchema: {
      type: "object",
      properties: {
        instruction: { type: "string", description: "Instruction text (e.g. 'Sort these animals by type')" },
        categories: {
          type: "object",
          description: "Object where each key is a category name and value is an array of items belonging to that category",
          additionalProperties: {
            type: "array",
            items: { type: "string" },
          },
        },
      },
      required: ["categories"],
    },
  },
  {
    name: "word_scramble",
    description: "Render a word scramble exercise. Letters of a word are shuffled and the user taps them in order to spell the correct word.",
    inputSchema: {
      type: "object",
      properties: {
        word: { type: "string", description: "The correct word to unscramble" },
        hint: { type: "string", description: "Optional hint or definition" },
      },
      required: ["word"],
    },
  },
  {
    name: "sentence_builder",
    description: "Render a sentence building exercise. Words are shown scrambled and the user taps them in order to construct the correct sentence.",
    inputSchema: {
      type: "object",
      properties: {
        sentence: { type: "string", description: "The correct sentence. Words will be scrambled for display." },
        hint: { type: "string", description: "Optional hint or translation" },
      },
      required: ["sentence"],
    },
  },
  {
    name: "highlight_select",
    description: "Render a text highlighting exercise. User taps words or phrases in a passage to select the correct ones.",
    inputSchema: {
      type: "object",
      properties: {
        instruction: { type: "string", description: "What to highlight (e.g. 'Tap all the adjectives')" },
        text: { type: "string", description: "The passage of text to highlight from" },
        correct: { type: "array", items: { type: "string" }, description: "The words/phrases that should be selected" },
      },
      required: ["instruction", "text", "correct"],
    },
  },
  {
    name: "error_correction",
    description: "Render an error correction exercise. A sentence contains errors and the user taps the incorrect words to reveal corrections.",
    inputSchema: {
      type: "object",
      properties: {
        instruction: { type: "string", description: "Instruction text (e.g. 'Find and tap the errors in this sentence')" },
        segments: {
          type: "array",
          description: "Sentence broken into segments. Each segment is either correct text or an error with its correction.",
          items: {
            type: "object",
            properties: {
              text: { type: "string", description: "The displayed text (may contain an error)" },
              correction: { type: "string", description: "The correct version. If present, this segment is an error." },
            },
            required: ["text"],
          },
        },
      },
      required: ["segments"],
    },
  },
  {
    name: "type_answer",
    description: "Render a free-text answer exercise. User types their answer and checks it against the correct answer. Harder than multiple choice — tests recall, not recognition.",
    inputSchema: {
      type: "object",
      properties: {
        question: { type: "string", description: "The question or prompt" },
        answer: { type: "string", description: "The correct answer to check against" },
        hint: { type: "string", description: "Optional hint shown before answering" },
        caseSensitive: { type: "boolean", description: "Whether the check is case-sensitive (default false)" },
      },
      required: ["question", "answer"],
    },
  },
  {
    name: "bar_chart",
    description: "Render a bar chart for comparing values. Great for histograms, frequency distributions, and category comparisons.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Chart title" },
        bars: {
          type: "array",
          description: "Array of bars, each with a label and value",
          items: {
            type: "object",
            properties: {
              label: { type: "string", description: "Bar label" },
              value: { type: "number", description: "Bar value" },
            },
            required: ["label", "value"],
          },
        },
        unit: { type: "string", description: "Optional unit label for the values (e.g. '%', 'kg')" },
        color: { type: "string", description: "Bar color: blue, green, orange, purple, red, teal, pink (default: blue)" },
      },
      required: ["bars"],
    },
  },
  {
    name: "pie_chart",
    description: "Render a pie chart showing proportions. Great for percentages, fractions, and part-of-whole relationships.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Chart title" },
        slices: {
          type: "array",
          description: "Array of slices, each with a label and value (values are proportional, don't need to sum to 100)",
          items: {
            type: "object",
            properties: {
              label: { type: "string", description: "Slice label" },
              value: { type: "number", description: "Slice value" },
            },
            required: ["label", "value"],
          },
        },
      },
      required: ["slices"],
    },
  },
  {
    name: "scatter_plot",
    description: "Render a scatter plot for showing data point relationships and correlations.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Chart title" },
        points: {
          type: "array",
          description: "Array of data points with x and y coordinates",
          items: {
            type: "object",
            properties: {
              x: { type: "number" },
              y: { type: "number" },
              label: { type: "string", description: "Optional point label" },
            },
            required: ["x", "y"],
          },
        },
        xLabel: { type: "string", description: "X axis label" },
        yLabel: { type: "string", description: "Y axis label" },
      },
      required: ["points"],
    },
  },
  {
    name: "line_chart",
    description: "Render a data-driven line chart for time series, trends, and sequences. Unlike function_plot, this takes explicit data points.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Chart title" },
        lines: {
          type: "array",
          description: "One or more data series to plot",
          items: {
            type: "object",
            properties: {
              label: { type: "string", description: "Series name for legend" },
              points: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    x: { type: "number", description: "X value or index" },
                    y: { type: "number", description: "Y value" },
                  },
                  required: ["x", "y"],
                },
              },
            },
            required: ["label", "points"],
          },
        },
        xLabel: { type: "string", description: "X axis label" },
        yLabel: { type: "string", description: "Y axis label" },
      },
      required: ["lines"],
    },
  },
  {
    name: "step_reveal",
    description: "Render a step-by-step reveal exercise. Steps are hidden and revealed one at a time as the user taps 'Next'. Forces active thinking before seeing each answer.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Title of the step sequence" },
        steps: {
          type: "array",
          items: { type: "string" },
          description: "The steps in order. Each is hidden until revealed.",
        },
      },
      required: ["steps"],
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
