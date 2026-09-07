/**
 * tuicr-gate - pre-commit review gate + tuicr comment bridge
 *
 * Replaces the hunk-gate extension: viewing/comments now go through tuicr
 * (https://github.com/agavra/tuicr) instead of hunk.
 *
 * Workflow:
 *   1. LLM tries `git commit` -> blocked by the gate (changes not reviewed)
 *   2. User/LLM opens a tuicr review in any terminal: `tuicr -w` (or `tuicr`)
 *   3. LLM adds inline comments with tuicr_comment_add (type=note, username=pi)
 *   4. User reviews in tuicr, presses `c` to comment on lines
 *   5. User returns to pi; LLM reads user notes via tuicr_comment_read --type user
 *   6. User runs `/tuicr approve` -> `git commit` allowed for the same change set
 *
 * Author convention: the agent always writes comments with comment_type "note".
 * `tuicr review comments` JSON does not expose the author, so "user notes" are
 * every comment whose type is NOT `note` (the agent reserves `note`).
 *
 * Depends on: tuicr CLI (https://github.com/agavra/tuicr), driven via `tuicr review`
 * State: ~/.pi/agent/tuicr-gate.json (approved diff hash)
 */

import { execSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { createHash } from "node:crypto";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

// ---------- utils ----------

const AGENT_TYPE = "note"; // reserved comment_type the agent always uses
const AGENT_USER = "pi"; // --username stamped on agent comments (visual split in TUI)

function shellEscape(s: string): string {
  return `'${s.replace(/'/g, `'\\''`)}'`;
}

function runTuicr(args: string[], opts: { cwd?: string; input?: string } = {}): { ok: boolean; out: string; code: number } {
  const cmd = `tuicr ${args.map(shellEscape).join(" ")}`;
  try {
    const out = execSync(cmd, {
      cwd: opts.cwd ?? process.cwd(),
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
      input: opts.input,
      timeout: 30_000,
    });
    return { ok: true, out: out.trim(), code: 0 };
  } catch (e: any) {
    const msg = (e?.stderr?.toString?.() || e?.stdout?.toString?.() || e?.message || "tuicr error").trim();
    return { ok: false, out: msg, code: e?.status ?? 1 };
  }
}

function hasTuicr(): boolean {
  try { execSync("tuicr --version", { stdio: "ignore" }); return true; } catch { return false; }
}

// ---------- gate state (same diff-hash approval as hunk-gate, new state file) ----------

interface GateState { approvedHash?: string; }

function stateFile(): string {
  return join(getAgentDir(), "tuicr-gate.json");
}

function loadGate(): GateState {
  try {
    if (existsSync(stateFile())) return JSON.parse(readFileSync(stateFile(), "utf-8"));
  } catch {}
  return {};
}

function saveGate(s: GateState) {
  writeFileSync(stateFile(), JSON.stringify(s, null, 2));
}

/** 当前工作区改动集合的 hash (diff HEAD + 状态) */
function currentDiffHash(cwd: string): string {
  try {
    const parts: string[] = [];
    try { parts.push(execSync("git diff HEAD", { cwd, encoding: "utf-8", maxBuffer: 64 * 1024 * 1024 })); } catch {}
    try { parts.push(execSync("git status --porcelain", { cwd, encoding: "utf-8", maxBuffer: 4 * 1024 * 1024 })); } catch {}
    return createHash("sha1").update(parts.join("\n---\n")).digest("hex").slice(0, 16);
  } catch { return ""; }
}

const COMMIT_RE = /(^|[;&|]|\b)git\s+commit\b/;

function isApproved(cwd: string): boolean {
  const st = loadGate();
  if (!st.approvedHash) return false;
  const h = currentDiffHash(cwd);
  return h !== "" && st.approvedHash === h;
}

// ---------- tuicr session helpers ----------

/** 列出当前 checkout 的 tuicr 本地 session (JSON array) */
function listSessions(cwd: string): { ok: boolean; out: string; sessions: any[] } {
  const r = runTuicr(["review", "list", "--repo", cwd], { cwd });
  if (!r.ok) return { ok: false, out: r.out, sessions: [] };
  try {
    const j = JSON.parse(r.out);
    return { ok: true, out: r.out, sessions: Array.isArray(j) ? j : [] };
  } catch {
    return { ok: false, out: r.out, sessions: [] };
  }
}

/** 解析可用于 add/comments 的 session slug: 优先 active, 其次最新的本地 session */
function activeSession(cwd: string): { slug?: string; active?: string; sessions: any[] } {
  const { sessions } = listSessions(cwd);
  if (!sessions.length) return { sessions };
  const live = sessions.find((s: any) => s.active === true);
  if (live) return { slug: live.slug, active: "yes", sessions };
  const local = sessions.filter((s: any) => s.kind === "local").sort(
    (a: any, b: any) => (b.updated_at ?? "").localeCompare(a.updated_at ?? "")
  )[0] ?? sessions[0];
  return { slug: local.slug, active: "no", sessions };
}

/** 提取当前 repo session 中的用户 note (comment_type != note) */
function getUserNotes(cwd: string): { text: string; count: number } {
  const act = activeSession(cwd);
  if (!act.slug) return { text: "", count: 0 };
  const r = runTuicr(["review", "comments", "--session", act.slug, "--repo", cwd], { cwd });
  if (!r.ok) return { text: "", count: 0 };
  try {
    const arr = JSON.parse(r.out);
    const user = (Array.isArray(arr) ? arr : []).filter((c: any) => c.comment_type !== AGENT_TYPE);
    if (!user.length) return { text: "", count: 0 };
    return {
      count: user.length,
      text: user.map((c: any) =>
        `[user note] ${c.path ?? "(review)"}${c.start_line ? `:${c.start_line}${c.end_line !== c.start_line ? `-${c.end_line}` : ""}` : ""} - ${c.content}`
      ).join("\n"),
    };
  } catch { return { text: "", count: 0 }; }
}

// ---------- format helper for comment list ----------

function formatComments(raw: string): string {
  try {
    const j = JSON.parse(raw);
    const arr: any[] = Array.isArray(j) ? j : [];
    if (arr.length === 0) return "(无注释)";
    return arr.map((c: any) => {
      const loc = c.location ?? [c.path, c.start_line].filter(Boolean).join(":") ?? "(review)";
      const side = c.side ? ` (${c.side})` : "";
      return `[${c.comment_type}] ${c.location || ""} - ${c.content}`.trim();
    }).join("\n");
  } catch { return raw; }
}

export default function (pi: ExtensionAPI) {

  // ---------- 1. commit gate ----------
  pi.on("tool_call", async (event, ctx) => {
    const input: any = (event as any).input;
    if (!input?.command || typeof input.command !== "string") return;
    if (!COMMIT_RE.test(input.command)) return;
    if (!hasTuicr()) return; // 无 tuicr 环境不拦
    if (isApproved(ctx.cwd)) return; // 已批准放行
    const notes = getUserNotes(ctx.cwd);
    input.command = [
      `echo "git commit 被 tuicr-gate 拦截: 当前改动尚未 review"`,
      `echo "流程: 1) 终端跑 'tuicr -w' (或调 tuicr_open) 打开 review 2) 用 tuicr_comment_add 加注释 3) 等用户看完并 /tuicr approve 4) 再 commit"`,
      ...(notes.count
        ? [`echo ""`, `echo "未处理的用户 note (先处理再 commit):"`, `echo ${shellEscape(notes.text)}`]
        : []),
      `exit 1`,
    ].join(" && ");
  });

  // ---------- 2. tuicr_open ----------
  pi.registerTool({
    name: "tuicr_open",
    label: "Tuicr Open",
    description: "打开/确认 tuicr review 会话。有 session 则报告其 slug 与 gate 状态; 没有则给出在另一终端启动 tuicr 的命令。之后可用 tuicr_comment_add 加注释、tuicr_comment_read 读用户注释。",
    parameters: Type.Object({}),
    async execute(_id, _p, _s, _u, ctx) {
      const cwd = ctx.cwd;
      if (!hasTuicr()) {
        return { content: [{ type: "text", text: "tuicr 未安装。安装: mise use github:agavra/tuicr 或 curl -fsSL tuicr.dev/install.sh | sh" }], details: { isError: true } };
      }
      const act = activeSession(cwd);
      const approved = isApproved(cwd);
      if (act.slug) {
        return {
          content: [{
            type: "text",
            text: `tuicr session:\n  slug=${act.slug}\n  active(TUI 开着)=${act.active}\n  sessions=\n${act.sessions.map((s: any) => `  - ${s.slug} (${s.kind}, active=${s.active}, comments=${s.comment_count})`).join("\n")}\n\ngate 状态: ${approved ? "已批准 (commit 放行)" : "未批准 (commit 被拦)"}`,
          }],
          details: { slug: act.slug ?? null, active: act.active, approved, hasSession: !!act.slug },
        };
      }
      return {
        content: [{
          type: "text",
          text: `无 tuicr session (tuicr review list --repo . 为空)。请在另一个终端运行:\n\n  tuicr -w\n\n(有 commit 未提交改动时; 或直接 tuicr 选 commit 范围)。启动后再调 tuicr_status 拿 session slug, 然后用 tuicr_comment_add 加注释。`,
        }],
        details: { opened: false },
      };
    },
  });

  // ---------- 3. tuicr_comment_add ----------
  pi.registerTool({
    name: "tuicr_comment_add",
    label: "Tuicr Comment Add",
    description: "在 tuicr review session 中加 inline 注释 (agent 侧)。始终用 comment_type=note、username=pi, 以便与用户注释区分 (用户 note = 非 note 类型)。单条指定 file + line; 批量用 batch JSON。",
    parameters: Type.Object({
      file: Type.Optional(Type.String({ description: "文件路径 (单条 add 必填; 省略则为 review 级注释)" })),
      line: Type.Optional(Type.Number({ description: "行号 (1-based, 新文件 side=new)" })),
      endLine: Type.Optional(Type.Number({ description: "区间结束行 (与 line 一起构成 range 注释)" })),
      side: Type.Optional(Type.String({ description: "old | new (默认 new)" })),
      summary: Type.Optional(Type.String({ description: "注释内容 (单条 add 必填)" })),
      batch: Type.Optional(Type.String({ description: "批量注释 JSON: {\"comments\":[{\"file\":\"a.ts\",\"line\":103,\"summary\":\"...\"}]}" })),
    }),
    async execute(_id, p, _s, _u, ctx) {
      const cwd = ctx.cwd;
      if (!hasTuicr()) return { content: [{ type: "text", text: "tuicr 未安装" }], details: { isError: true } };
      const act = activeSession(cwd);
      if (!act.slug) {
        return { content: [{ type: "text", text: "无 tuicr session。先让用户开 tuicr (tuicr_open 有指引), 拿到 session slug 后才能加注释。" }], details: { isError: true } };
      }

      const doAdd = (c: { file?: string; line?: number; endLine?: number; side?: string; summary: string }): { ok: boolean; out: string } => {
        const payload: any = { content: c.summary, type: AGENT_TYPE }; // type/comment_type in JSON
        if (c.file) payload.file = c.file;
        if (c.line != null) {
          if (c.endLine != null) { payload.start_line = c.line; payload.end_line = c.endLine; }
          else payload.line = c.line;
        }
        if (c.side) payload.side = c.side;
        const r = runTuicr(["review", "add", "--session", act.slug!, "--repo", cwd, "--username", AGENT_USER, "--input", "-"], { cwd, input: JSON.stringify(payload) });
        return r.ok
          ? { ok: true, out: r.out }
          : { ok: false, out: r.out };
      };

      // 批量
      if (p.batch) {
        let parsed: any;
        try { parsed = JSON.parse(p.batch); } catch { return { content: [{ type: "text", text: "batch 不是合法 JSON" }], details: { isError: true } }; }
        const list: any[] = Array.isArray(parsed) ? parsed : parsed.comments;
        if (!Array.isArray(list) || !list.length) return { content: [{ type: "text", text: "batch 缺数组 (comments[])" }], details: { isError: true } };
        const fail: string[] = [];
        for (const c of list) {
          const r = doAdd({ file: c.file, line: c.line, endLine: c.endLine, side: c.side, summary: c.summary ?? c.content });
          if (!r.ok) fail.push(`${c.file ?? "?"}:${c.line ?? "?"} - ${r.out}`);
        }
        return fail.length
          ? { content: [{ type: "text", text: `批量注释: ${list.length - fail.length} 成功, ${fail.length} 失败:\n${fail.join("\n")}` }], details: { ok: false, failed: fail.length } }
          : { content: [{ type: "text", text: `已批量添加 ${list.length} 条注释到 ${act.slug}` }], details: { ok: true, count: list.length } };
      }

      if (!p.summary) {
        return { content: [{ type: "text", text: "单条 add 需要 summary (可加 file + line)" }], details: { isError: true } };
      }
      const r = doAdd({ file: p.file, line: p.line, endLine: p.endLine, side: p.side, summary: p.summary });
      return r.ok
        ? { content: [{ type: "text", text: `已添加注释 ${p.file ?? "(review)"}:${p.line ?? (p.endLine ? `${p.line}-${p.endLine}` : "?")} - ${p.summary}` }], details: { ok: true } }
        : { content: [{ type: "text", text: `添加注释失败: ${r.out}` }], details: { isError: true } };
    },
  });

  // ---------- 4. tuicr_comment_read ----------
  pi.registerTool({
    name: "tuicr_comment_read",
    label: "Tuicr Comment Read",
    description: "读取 tuicr review session 中的注释。--type user 只读用户写的 note (即 comment_type != note, agent 的 note 类型被排除)。默认读全部。",
    parameters: Type.Object({
      type: Type.Optional(Type.String({ description: "all (默认) | user (用户反馈, 排除 agent 的 note 类型)" })),
    }),
    async execute(_id, p, _s, _u, ctx) {
      const cwd = ctx.cwd;
      if (!hasTuicr()) return { content: [{ type: "text", text: "tuicr 未安装" }], details: { isError: true } };
      const act = activeSession(cwd);
      if (!act.slug) return { content: [{ type: "text", text: "无 tuicr session (先让用户开 tuicr)" }], details: { isError: true } };
      const r = runTuicr(["review", "comments", "--session", act.slug, "--repo", cwd], { cwd });
      if (!r.ok) return { content: [{ type: "text", text: `读取注释失败: ${r.out}` }], details: { isError: true } };
      let final = r.out;
      try {
        const arr = JSON.parse(r.out);
        let list: any[] = Array.isArray(arr) ? arr : [];
        if ((p.type ?? "all") === "user") list = list.filter((c: any) => c.comment_type !== AGENT_TYPE);
        final = formatComments(JSON.stringify(list));
      } catch {}
      return { content: [{ type: "text", text: final.slice(0, 30_000) }], details: { ok: true } };
    },
  });

  // ---------- 5. tuicr_status ----------
  pi.registerTool({
    name: "tuicr_status",
    label: "Tuicr Status",
    description: "检查 tuicr review session 与 commit gate 状态。commit 被拦时先调这个确认。",
    parameters: Type.Object({}),
    async execute(_id, _p, _s, _u, ctx) {
      const cwd = ctx.cwd;
      const ok = hasTuicr();
      const act = ok ? activeSession(cwd) : { slug: undefined, active: "no", sessions: [] };
      const approved = isApproved(cwd);
      const notes = getUserNotes(cwd);
      const lines = [
        `tuicr: ${ok ? "ok" : "未安装"}`,
        `session: ${ok && act.slug ? `${act.slug} (TUI active=${act.active})` : "无"}`,
        `commit gate: ${approved ? "已批准 (commit 放行)" : "未批准 (commit 被拦截)"}`,
        `unhandled user notes: ${notes.count}`,
      ];
      if (ok && act.sessions.length) {
        lines.push(`\nsessions:\n${act.sessions.map((s: any) => `  - ${s.slug} (${s.kind}, active=${s.active}, comments=${s.comment_count})`).join("\n")}`);
      }
      return { content: [{ type: "text", text: lines.join("\n") }], details: { approved, hasSession: !!act.slug, userNotes: notes.count } };
    },
  });

  // ---------- 6. /tuicr 命令 ----------
  pi.registerCommand("tuicr", {
    description: "tuicr review gate: status / open / approve / block / notes",
    handler: async (args, ctx) => {
      const cwd = ctx.cwd;
      const sub = (args || "").trim().toLowerCase();

      if (sub === "approve") {
        const h = currentDiffHash(cwd);
        if (!h) { ctx.ui.notify("tuicr: 当前目录没有 git 改动可批准", "warning"); return; }
        saveGate({ approvedHash: h });
        ctx.ui.notify(`tuicr: 已批准当前改动 (${h}), git commit 放行`, "info");
        pi.sendUserMessage(
          `tuicr review 已批准 (${h}), 当前改动可以 git commit 了。`,
          { deliverAs: "steer" }
        );
        return;
      }
      if (sub === "block" || sub === "reset") {
        saveGate({});
        ctx.ui.notify("tuicr: gate 已重新锁定, git commit 将被拦截", "info");
        return;
      }
      if (sub.startsWith("continue")) {
        const notes = getUserNotes(cwd);
        if (!notes.count) {
          ctx.ui.notify("tuicr: 当前 session 没有用户 note (写完 note 后回来输入 /tuicr continue)", "info");
          return;
        }
        pi.sendUserMessage(
          `tuicr review 里有用户 note, 请逐条读取并处理 (改完可以 git commit, 但需用户 /tuicr approve 才放行):\n\n${notes.text}`,
          { deliverAs: "steer" }
        );
        ctx.ui.notify("tuicr: 已把用户 note 交给 LLM 处理", "info");
        return;
      }
      if (sub.startsWith("open")) {
        if (!hasTuicr()) { ctx.ui.notify("tuicr 未安装: mise use github:agavra/tuicr", "error"); return; }
        const act = activeSession(cwd);
        if (act.slug) { ctx.ui.notify(`tuicr: 已有 session ${act.slug} (TUI active=${act.active})`, "info"); return; }
        ctx.ui.notify("tuicr: 在另一个终端运行 → tuicr -w\n(有未提交改动时; 或直接 tuicr 选 commit 范围)", "info");
        return;
      }
      if (sub.startsWith("notes")) {
        const rest = sub.replace(/^notes\s*/, "").trim();
        const act = activeSession(cwd);
        if (!act.slug) { ctx.ui.notify("tuicr: 无 session", "error"); return; }
        const r = runTuicr(["review", "comments", "--session", act.slug, "--repo", cwd], { cwd });
        let text = r.out;
        if (rest === "user") { try { text = formatComments(JSON.stringify((JSON.parse(r.out) as any[]).filter((c: any) => c.comment_type !== AGENT_TYPE))); } catch {} }
        ctx.ui.notify(r.ok ? text.slice(0, 3000) : `读取失败: ${r.out}`, r.ok ? "info" : "error");
        return;
      }
      // status
      const ok = hasTuicr();
      const act = ok ? activeSession(cwd) : { slug: undefined, active: "no", sessions: [] };
      const approved = isApproved(cwd);
      const notes = getUserNotes(cwd);
      ctx.ui.notify(
        `tuicr-gate status:\n  tuicr: ${ok ? "ok" : "未安装"}\n  session: ${ok && act.slug ? act.slug : "无"}\n  commit gate: ${approved ? "已批准" : "未批准"}\n  user notes: ${notes.count}\n\n命令:\n  /tuicr open                 提示打开 tuicr review (tuicr -w)\n  /tuicr continue             读取用户 note 并交给 LLM 处理\n  /tuicr approve              批准当前改动 (解锁 commit)\n  /tuicr block                重新锁定\n  /tuicr notes [user]         列出注释`,
        "info"
      );
    },
  });
}