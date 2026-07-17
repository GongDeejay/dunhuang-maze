#!/usr/bin/env node
/**
 * Minimal MCP (stdio) — Web export for 敦煌迷途.
 * Complements Beckett Lite (no export_project). Tools: export_web, run_tests.
 */
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "../..");

const TOOLS = [
  {
    name: "export_web",
    description: "Headless export Godot Web build to web/index.html (PC + mobile browser).",
    inputSchema: {
      type: "object",
      properties: {
        release: { type: "boolean", description: "Use --export-release (default true)" },
      },
    },
  },
  {
    name: "run_tests",
    description: "Run headless test suite via run_tests.sh",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "beckett_status",
    description: "Check if Beckett Godot MCP (port 8770) is reachable",
    inputSchema: { type: "object", properties: {} },
  },
];

function send(msg) {
  process.stdout.write(JSON.stringify(msg) + "\n");
}

function runShell(script, args = []) {
  return new Promise((resolve) => {
    const child = spawn(script, args, { cwd: ROOT, shell: true });
    let out = "";
    let err = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (err += d));
    child.on("close", (code) => resolve({ code, out: out + err }));
  });
}

async function handleTool(name, args) {
  if (name === "export_web") {
    const r = await runShell("./export_web.sh");
    const ok = r.code === 0;
    return {
      content: [
        {
          type: "text",
          text: ok
            ? `Web export OK → web/index.html\n${r.out.slice(-1200)}`
            : `Web export FAILED (code ${r.code})\n${r.out.slice(-2000)}`,
        },
      ],
      isError: !ok,
    };
  }
  if (name === "run_tests") {
    const r = await runShell("./run_tests.sh");
    return {
      content: [{ type: "text", text: r.out.slice(-2500) }],
      isError: r.code !== 0,
    };
  }
  if (name === "beckett_status") {
    try {
      const res = await fetch("http://127.0.0.1:8770/mcp", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-03-26", capabilities: {}, clientInfo: { name: "export-mcp", version: "1" } } }) });
      const text = await res.text();
      return { content: [{ type: "text", text: `Beckett MCP: HTTP ${res.status}\n${text.slice(0, 500)}` }] };
    } catch (e) {
      return { content: [{ type: "text", text: `Beckett MCP offline. Open Godot editor with Beckett plugin enabled.\n${e}` }], isError: true };
    }
  }
  return { content: [{ type: "text", text: `Unknown tool: ${name}` }], isError: true };
}

const rl = createInterface({ input: process.stdin, terminal: false });
rl.on("line", async (line) => {
  let req;
  try {
    req = JSON.parse(line);
  } catch {
    return;
  }
  const { id, method, params } = req;
  if (method === "initialize") {
    send({
      jsonrpc: "2.0",
      id,
      result: {
        protocolVersion: "2024-11-05",
        capabilities: { tools: {} },
        serverInfo: { name: "dunhuang-godot-export", version: "1.0.0" },
      },
    });
    return;
  }
  if (method === "notifications/initialized") return;
  if (method === "tools/list") {
    send({ jsonrpc: "2.0", id, result: { tools: TOOLS } });
    return;
  }
  if (method === "tools/call") {
    const result = await handleTool(params.name, params.arguments || {});
    send({ jsonrpc: "2.0", id, result });
    return;
  }
  send({ jsonrpc: "2.0", id, error: { code: -32601, message: `Method not found: ${method}` } });
});
