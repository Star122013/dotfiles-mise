/**
 * hunk-gate - pre-commit review gate + hunk comment bridge
 *
 * Workflow:
 *   1. LLM tries `git commit` -> blocked by the gate (changes not reviewed)
 *   2. User/LLM opens a hunk review (`hunk diff` in any terminal)
 *   3. LLM adds inline comments with hunk_comment_add (analysis / rationale)
 *   4. User reads the diff + comments in hunk, presses `c` to write own notes
 *   5. User returns to pi; LLM reads user notes via hunk_comment_read and acts on them
 *   6. User runs `/hunk approve` -> `git commit` allowed for the same change set
 *
 * Depends on: hunk CLI (https://github.com/modem-dev/hunk), drives live sessions via `hunk session`
 * State: ~/.pi/agent/hunk-gate.json (approved diff hash)
 */

import { execSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { createHash } from "node:crypto";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getAgentDir } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

// ---------- utils ----------

function shellEscape(s: string): string {
  return `'${s.replace(/'/g, `'\\''`)}'`;
}

function runHunk(args: string[], opts: { cwd?: string; input?: string } = {}): { ok: boolean; out: string; code: number } {
  const cmd = `hunk ${args.map(shellEscape).join(" ")}`;
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
    const msg = (e?.stderr?.toString?.() || e?.stdout?.toString?.() || e?.message || "hunk error").trim();
    return { ok: false, out: msg, code: e?.status ?? 1 };
  }
}

function hasHunk(): boolean {
  try { execSync("hunk --version", { stdio: "ignore" }); return true; } catch { return false; }
}

function repoArgs(repo?: string): string[] {
  return repo ? ["--repo", repo] : [];
}

// ---------- gate state ----------

interface GateState { approvedHash?: string; }

function stateFile(): string {
  return join(getAgentDir(), "hunk-gate.json");
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

// ---------- hunk session helpers ----------

function listSessions(cwd: string): { ok: boolean; out: string } {
  return runHunk(["session", "list", "--json"], { cwd });
}

function hasLiveSession(cwd: string): boolean {
  const r = listSessions(cwd);
  if (!r.ok || !r.out) return false;
  try {
    const j = JSON.parse(r.out);
    return Array.isArray(j?.sessions) && j.sessions.length > 0;
  } catch { return false; }
}

/** 提取当前仓库 live 会话中的用户 note (snapshot.reviewNotes) */
function getReviewNotes(cwd: string): string {
  const r = listSessions(cwd);
  if (!r.ok || !r.out) return "";
  try {
    const j = JSON.parse(r.out);
    const sessions: any[] = j?.sessions ?? [];
    if (!sessions.length) return "";
    const s = sessions.find((x: any) => x.repoRoot === cwd) ?? sessions[0];
    const notes: any[] = s?.snapshot?.state?.reviewNotes ?? [];
    if (!notes.length) return "";
    return notes.map((n: any) => `[${n.author ?? "user"} note] ${n.filePath}:${n.newRange?.[0] ?? "?"} - ${n.body}`).join("\n");
  } catch { return ""; }
}

export default function (pi: ExtensionAPI) {

  // ---------- 1. commit gate ----------
  pi.on("tool_call", async (event, ctx) => {
    const input: any = (event as any).input;
    if (!input?.command || typeof input.command !== "string") return;
    if (!COMMIT_RE.test(input.command)) return;
    if (!hasHunk()) return; // 无 hunk 环境不拦
    if (isApproved(ctx.cwd)) return; // 已批准放行
    const notes = getReviewNotes(ctx.cwd);
    input.command = [
      `echo "git commit 被 hunk-gate 拦截: 当前改动尚未 review"`,
      `echo "流程: 1) 终端跑 'hunk diff' (或调 hunk_open) 打开 review 2) 用 hunk_comment_add 加注释 3) 等用户看完并 /hunk approve 4) 再 commit"`,
      ...(notes
        ? [`echo ""`, `echo "未处理的用户 note (先处理再 commit):"`, `echo ${shellEscape(notes)}`]
        : []),
      `exit 1`,
    ].join(" && ");
  });

  // ---------- 2. hunk_open ----------
  pi.registerTool({
    name: "hunk_open",
    label: "Hunk Open",
    description: "打开或确认 hunk review 会话。有 live 会话则报告状态; 没有则给出在另一终端启动 hunk 的命令。启动后可用 hunk_comment_add 加注释、hunk_comment_read 读用户注释。",
    parameters: Type.Object({
      command: Type.Optional(Type.String({ description: "review 内容: diff (默认) | show <rev> | staged", default: "diff" })),
    }),
    async execute(_id, p, _s, _u, ctx) {
      const cwd = ctx.cwd;
      if (!hasHunk()) {
        return { content: [{ type: "text", text: "hunk 未安装。安装: mise use -g hunk 或 curl -fsSL https://hunk.dev/install.sh | sh" }], details: { isError: true } };
      }
      if (hasLiveSession(cwd)) {
        const s = listSessions(cwd);
        const g = loadGate();
        const approved = isApproved(cwd);
        return {
          content: [{ type: "text", text: `已有 live hunk 会话:\n${s.out}\n\ngate 状态: ${approved ? "已批准 (commit 放行)" : "未批准 (commit 被拦)"}${g.approvedHash ? "" : ", 无批准记录"}` }],
          details: { opened: true, approved },
        };
      }
      const cmd = p.command ?? "diff";
      return {
        content: [{ type: "text", text: `无 live hunk 会话。请在另一个终端运行:\n\n  hunk ${cmd}\n\n启动后再调 hunk_status 确认会话, 然后用 hunk_comment_add 加注释。` }],
        details: { opened: false },
      };
    },
  });

  // ---------- 3. hunk_comment_add ----------
  pi.registerTool({
    name: "hunk_comment_add",
    label: "Hunk Comment Add",
    description: "在 live hunk 会话中加 inline 注释 (agent 侧)。单条用 add (file + 行定位 + summary); 多条用 batch (JSON, 走 comment apply)。注释会实时显示在用户 hunk 窗口。",
    parameters: Type.Object({
      file: Type.Optional(Type.String({ description: "文件路径 (单条 add 必填)" })),
      newLine: Type.Optional(Type.Number({ description: "新文件行号 (1-based, 与 oldLine 二选一)" })),
      oldLine: Type.Optional(Type.Number({ description: "旧文件行号 (1-based, 与 newLine 二选一)" })),
      hunkNumber: Type.Optional(Type.Number({ description: "hunk 序号 (1-based), 替代行号定位" })),
      summary: Type.Optional(Type.String({ description: "注释内容 (单条 add 必填)" })),
      rationale: Type.Optional(Type.String({ description: "补充说明" })),
      focus: Type.Optional(Type.Boolean({ description: "跳转到该注释" })),
      batch: Type.Optional(Type.String({ description: "批量注释 JSON: {\"comments\":[{\"filePath\":\"a.ts\",\"newLine\":103,\"summary\":\"...\"}]}" })),
    }),
    async execute(_id, p, _s, _u, ctx) {
      const cwd = ctx.cwd;
      if (!hasHunk()) return { content: [{ type: "text", text: "hunk 未安装" }], details: { isError: true } };
      if (!hasLiveSession(cwd)) {
        return { content: [{ type: "text", text: "无 live hunk 会话。先让用户开 hunk (hunk_open 有指引)。" }], details: { isError: true } };
      }
      const sel = repoArgs(cwd);
      if (p.batch) {
        const r = runHunk(["session", "comment", "apply", ...sel, "--stdin", "--json"], { cwd, input: p.batch });
        return r.ok
          ? { content: [{ type: "text", text: `已批量添加注释:\n${r.out.slice(0, 4000)}` }], details: { ok: true } }
          : { content: [{ type: "text", text: `批量注释失败: ${r.out}` }], details: { isError: true } };
      }
      if (!p.file || !p.summary) {
        return { content: [{ type: "text", text: "单条 add 需要 file + summary (+ newLine/oldLine/hunkNumber 之一)" }], details: { isError: true } };
      }
      const args = ["session", "comment", "add", ...sel, "--file", p.file];
      if (p.hunkNumber != null) args.push("--hunk", String(p.hunkNumber));
      else if (p.newLine != null) args.push("--new-line", String(p.newLine));
      else if (p.oldLine != null) args.push("--old-line", String(p.oldLine));
      else return { content: [{ type: "text", text: "需要 newLine/oldLine/hunkNumber 之一" }], details: { isError: true } };
      args.push("--summary", p.summary);
      if (p.rationale) args.push("--rationale", p.rationale);
      if (p.focus) args.push("--focus");
      args.push("--json");
      const r = runHunk(args, { cwd });
      return r.ok
        ? { content: [{ type: "text", text: `已添加注释 ${p.file}:${p.newLine ?? p.oldLine ?? `hunk ${p.hunkNumber}`} - ${p.summary}` }], details: { ok: true } }
        : { content: [{ type: "text", text: `添加注释失败: ${r.out}` }], details: { isError: true } };
    },
  });

  // ---------- 4. hunk_comment_read ----------
  pi.registerTool({
    name: "hunk_comment_read",
    label: "Hunk Comment Read",
    description: "读取 live hunk 会话中的注释。默认读全部; type=user 只读用户手写注释 (review 反馈)。用 --type user 检查用户是否已写完 note。",
    parameters: Type.Object({
      type: Type.Optional(Type.String({ description: "live | all | ai | agent | user (默认 all)" })),
      file: Type.Optional(Type.String({ description: "只看某个文件" })),
    }),
    async execute(_id, p, _s, _u, ctx) {
      const cwd = ctx.cwd;
      if (!hasHunk()) return { content: [{ type: "text", text: "hunk 未安装" }], details: { isError: true } };
      const args = ["session", "comment", "list", ...repoArgs(cwd), "--json"];
      if (p.file) args.push("--file", p.file);
      if (p.type) args.push("--type", p.type);
      const r = runHunk(args, { cwd });
      if (!r.ok) return { content: [{ type: "text", text: `读取注释失败: ${r.out}` }], details: { isError: true } };
      // 格式化输出, 便于 LLM 消费
      let text = r.out;
      try {
        const j = JSON.parse(r.out);
        const notes: any[] = j?.notes ?? j?.comments ?? [];
        if (notes.length === 0) text = `(无 ${p.type ?? "任何"} 注释)`;
        else {
          text = notes.map((n: any) => {
            const kind = n.kind ?? n.author ?? "note";
            const loc = [n.filePath ?? n.file, n.newLine ?? n.oldLine ?? n.line ? `${n.newLine ?? n.oldLine ?? n.line}` : ""].filter(Boolean).join(":");
            return `[${kind}] ${loc}\n  ${n.summary ?? n.text ?? JSON.stringify(n)}`;
          }).join("\n");
        }
      } catch {}
      return { content: [{ type: "text", text: text.slice(0, 30_000) }], details: { ok: true } };
    },
  });

  // ---------- 5. hunk_status ----------
  pi.registerTool({
    name: "hunk_status",
    label: "Hunk Status",
    description: "检查 hunk review 会话与 commit gate 状态。commit 被拦时先调这个确认情况。",
    parameters: Type.Object({}),
    async execute(_id, _p, _s, _u, ctx) {
      const cwd = ctx.cwd;
      const hunkOk = hasHunk();
      const session = hunkOk ? listSessions(cwd) : { ok: false, out: "hunk 未安装" };
      const approved = isApproved(cwd);
      const lines = [
        `hunk: ${hunkOk ? "ok" : "未安装"}`,
        `live session: ${session.ok && hasLiveSession(cwd) ? "有" : "无"}`,
        `commit gate: ${approved ? "已批准 (commit 放行)" : "未批准 (commit 被拦截)"}`,
      ];
      if (session.ok && session.out) lines.push(`\nsessions:\n${session.out.slice(0, 2000)}`);
      return { content: [{ type: "text", text: lines.join("\n") }], details: { approved, hasSession: hasLiveSession(cwd) } };
    },
  });

  // ---------- 6. /hunk 命令 ----------
  pi.registerCommand("hunk", {
    description: "hunk review gate: status / open / approve / block / notes",
    handler: async (args, ctx) => {
      const cwd = ctx.cwd;
      const sub = (args || "").trim().toLowerCase();

      if (sub === "approve") {
        const h = currentDiffHash(cwd);
        if (!h) { ctx.ui.notify("hunk: 当前目录没有 git 改动可批准", "warning"); return; }
        saveGate({ approvedHash: h });
        ctx.ui.notify(`hunk: 已批准当前改动 (${h}), git commit 放行`, "info");
        // 自动通知 LLM, 无需用户再手动说一遍
        pi.sendUserMessage(
          `hunk review 已批准 (${h}), 当前改动可以 git commit 了。`,
          { deliverAs: "steer" }
        );
        return;
      }
      if (sub === "block" || sub === "reset") {
        saveGate({});
        ctx.ui.notify("hunk: gate 已重新锁定, git commit 将被拦截", "info");
        return;
      }
      if (sub.startsWith("continue")) {
        const notes = getReviewNotes(cwd);
        if (!notes) {
          ctx.ui.notify("hunk: 当前会话没有用户 note (写完 note 后回来输入 /hunk continue)", "info");
          return;
        }
        pi.sendUserMessage(
          `hunk review 里有用户 note, 请逐条读取并处理 (改完可以 git commit, 但需用户 /hunk approve 才放行):\n\n${notes}`,
          { deliverAs: "steer" }
        );
        ctx.ui.notify("hunk: 已把用户 note 交给 LLM 处理", "info");
        return;
      }
      if (sub.startsWith("open")) {
        const rest = sub.replace(/^open\s*/, "").trim() || "diff";
        if (!hasHunk()) { ctx.ui.notify("hunk 未安装: mise use -g hunk", "error"); return; }
        if (hasLiveSession(cwd)) {
          ctx.ui.notify("hunk: 已有 live 会话, 无需重新打开", "info");
          return;
        }
        ctx.ui.notify(`hunk: 在另一个终端运行 → hunk ${rest}\n(或按一次 Enter 后手动开)` , "info");
        return;
      }
      if (sub.startsWith("notes")) {
        const rest = sub.replace(/^notes\s*/, "").trim();
        const args2 = ["session", "comment", "list", ...repoArgs(cwd), "--json"];
        if (rest) args2.push("--type", rest);
        const r = runHunk(args2, { cwd });
        ctx.ui.notify(r.ok ? r.out.slice(0, 3000) : `读取失败: ${r.out}`, r.ok ? "info" : "error");
        return;
      }
      // status
      const hunkOk = hasHunk();
      const approved = isApproved(cwd);
      const sess = hunkOk ? (hasLiveSession(cwd) ? "有" : "无") : "hunk 未安装";
      ctx.ui.notify(
        `hunk-gate status:\n  hunk: ${hunkOk ? "ok" : "未安装"}\n  live session: ${sess}\n  commit gate: ${approved ? "已批准" : "未批准"}\n\n命令:\n  /hunk open [diff|show X|staged]   提示打开 hunk review\n  /hunk continue                  读取用户 note 并交给 LLM 处理\n  /hunk approve                   批准当前改动 (解锁 commit)\n  /hunk block                     重新锁定\n  /hunk notes [type]              列出注释 (user|all|...)`,
        "info"
      );
    },
  });
}
