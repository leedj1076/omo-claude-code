#!/usr/bin/env node
/**
 * Model Hub MCP Server
 * Exposes external AI models (GPT, Gemini) as MCP tools.
 * Used by codex-deep and gemini-ui bridge agents via inline mcpServers.
 *
 * Transport: stdio
 * Tools: ask_gpt, ask_gemini
 * Auth: CLI OAuth primary (codex exec, gemini -p), API key fallback
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { execSync } from "node:child_process";

const server = new Server(
  { name: "model-hub", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

// Tool definitions
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "ask_gpt",
      description:
        "Query OpenAI GPT for analysis, second opinions, or alternative implementations. Returns the model response.",
      inputSchema: {
        type: "object",
        properties: {
          prompt: {
            type: "string",
            description: "The prompt to send to GPT",
          },
          model: {
            type: "string",
            description: "Model ID (default: gpt-5.4)",
            default: "gpt-5.4",
          },
        },
        required: ["prompt"],
      },
    },
    {
      name: "ask_gemini",
      description:
        "Query Google Gemini for visual analysis, frontend feedback, or alternative perspectives. Returns the model response.",
      inputSchema: {
        type: "object",
        properties: {
          prompt: {
            type: "string",
            description: "The prompt to send to Gemini",
          },
          model: {
            type: "string",
            description: "Model ID (default: gemini-3.1-pro-preview)",
            default: "gemini-3.1-pro-preview",
          },
        },
        required: ["prompt"],
      },
    },
  ],
}));

// Tool execution
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (name === "ask_gpt") {
    return await callOpenAI(args.prompt, args.model || "gpt-5.4");
  }

  if (name === "ask_gemini") {
    return await callGemini(args.prompt, args.model || "gemini-3.1-pro-preview");
  }

  return {
    content: [{ type: "text", text: `Unknown tool: ${name}` }],
    isError: true,
  };
});

async function callOpenAI(prompt, model) {
  // Primary: Codex CLI with OAuth (no API key needed)
  try {
    const codexPath = findBinary("codex");
    if (codexPath) {
      const modelFlag = `--model ${model}`;
      const result = execSync(
        `${codexPath} exec --skip-git-repo-check ${modelFlag} -c model_reasoning_effort="xhigh" ${shellEscape(prompt)}`,
        { encoding: "utf-8", timeout: 1800000, stdio: ["pipe", "pipe", "pipe"] }
      );
      const cleaned = result
        .replace(/^codex\n/, "")
        .replace(/\ntokens used.*$/s, "")
        .trim();
      if (cleaned) {
        return {
          content: [{ type: "text", text: `**Model**: ${model} (via Codex CLI)\n\n${cleaned}` }],
        };
      }
    }
  } catch (e) {
    const cliError = (e.stderr || e.stdout || e.message || "").toString().trim();
    // Surface quota/auth errors directly instead of falling through
    if (cliError.match(/quota|rate.?limit|exhausted|capacity/i)) {
      return {
        content: [{ type: "text", text: `Codex CLI error: ${cliError}` }],
        isError: true,
      };
    }
    // Other CLI failures fall through to API key
  }

  // Fallback: API key + fetch
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    return {
      content: [{
        type: "text",
        text: `Error: Codex CLI not available and OPENAI_API_KEY not set. Run 'codex login' or set OPENAI_API_KEY.${findBinary("codex") ? "" : " (codex binary not found in PATH)"}`,
      }],
      isError: true,
    };
  }

  try {
    const response = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          messages: [{ role: "user", content: prompt }],
        }),
      }
    );

    const data = await response.json();

    if (!response.ok) {
      return {
        content: [{
          type: "text",
          text: `OpenAI API error (${response.status}): ${data.error?.message || JSON.stringify(data)}`,
        }],
        isError: true,
      };
    }

    const text = data.choices?.[0]?.message?.content || "No response";
    const tokens = data.usage?.total_tokens || 0;

    return {
      content: [{
        type: "text",
        text: `**Model**: ${model} (via API)\n**Tokens**: ${tokens}\n\n${text}`,
      }],
    };
  } catch (err) {
    return {
      content: [{ type: "text", text: `OpenAI request failed: ${err.message}` }],
      isError: true,
    };
  }
}

async function callGemini(prompt, model) {
  // Primary: Gemini CLI with OAuth (no API key needed)
  try {
    const geminiPath = findBinary("gemini");
    if (geminiPath) {
      const modelFlag = `-m ${model}`;
      const result = execSync(
        `${geminiPath} -p ${shellEscape(prompt)} ${modelFlag} --thinking-budget -1`,
        { encoding: "utf-8", timeout: 1800000, stdio: ["pipe", "pipe", "pipe"] }
      );
      const cleaned = result.trim();
      if (cleaned) {
        return {
          content: [{ type: "text", text: `**Model**: ${model} (via Gemini CLI)\n\n${cleaned}` }],
        };
      }
    }
  } catch (e) {
    const cliError = (e.stderr || e.stdout || e.message || "").toString().trim();
    // Surface quota/auth errors directly instead of falling through
    if (cliError.match(/quota|rate.?limit|exhausted|capacity/i)) {
      return {
        content: [{ type: "text", text: `Gemini CLI error: ${cliError}` }],
        isError: true,
      };
    }
    // Other CLI failures fall through to API key
  }

  // Fallback: API key + fetch
  const apiKey = process.env.GOOGLE_API_KEY;
  if (!apiKey) {
    return {
      content: [{
        type: "text",
        text: `Error: Gemini CLI not available and GOOGLE_API_KEY not set. Run 'gemini' to login or set GOOGLE_API_KEY.${findBinary("gemini") ? "" : " (gemini binary not found in PATH)"}`,
      }],
      isError: true,
    };
  }

  try {
    const url = `https://generativelanguage.googleapis.com/v1/models/${model}:generateContent?key=${apiKey}`;
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      return {
        content: [{
          type: "text",
          text: `Gemini API error (${response.status}): ${data.error?.message || JSON.stringify(data)}`,
        }],
        isError: true,
      };
    }

    const text =
      data.candidates?.[0]?.content?.parts?.[0]?.text || "No response";
    const tokens =
      (data.usageMetadata?.promptTokenCount || 0) +
      (data.usageMetadata?.candidatesTokenCount || 0);

    return {
      content: [{
        type: "text",
        text: `**Model**: ${model} (via API)\n**Tokens**: ${tokens}\n\n${text}`,
      }],
    };
  } catch (err) {
    return {
      content: [{ type: "text", text: `Gemini request failed: ${err.message}` }],
      isError: true,
    };
  }
}

// Utility: find a binary in PATH
function findBinary(name) {
  try {
    return execSync(`which ${name}`, { encoding: "utf-8", stdio: ["pipe", "pipe", "pipe"] }).trim();
  } catch {
    return null;
  }
}

// Utility: escape a string for shell usage
function shellEscape(str) {
  return "'" + str.replace(/'/g, "'\\''") + "'";
}

// Start server
const transport = new StdioServerTransport();
await server.connect(transport);
