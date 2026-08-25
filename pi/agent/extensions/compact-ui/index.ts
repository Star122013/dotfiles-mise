/**
 * compact-ui - 细线紧凑风格工具渲染插件 (UI 部分)
 *
 * 重写内置工具 (bash/read/write/edit/find/grep/ls) 的渲染:
 * - renderShell:"self" 去掉默认大灰框，折叠为单行
 * - 调用行: ╭─ kind args (超长截断)
 * - 结果行: ╰─ status body …(+N lines)
 * - ctrl+e 展开看原文
 *
 * 独立插件, 与 toolbox 完全无关 (不 import 其任何代码)。
 * 开关 = 插件是否被加载 (settings.json extensions 数组)。
 * 动态开关: /compact-ui on|off (写 ~/.pi/agent/compact-ui.json, /reload 生效)
 *
 * 配置 (优先级: 项目 > 全局 > 默认):
 * - ~/.pi/agent/compact-ui.json
 * - .pi/compact-ui.json
 * {
 *   "enabled": true
 * }
 */

import { Text } from "@earendil-works/pi-tui";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  createBashTool, createReadTool, createWriteTool, createEditTool,
  createFindTool, createGrepTool, createLsTool,
} from "@earendil-works/pi-coding-agent";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { CONFIG_DIR_NAME, getAgentDir } from "@earendil-works/pi-coding-agent";

// ---- 配置: enabled 开关 ----
function loadEnabled(cwd: string): boolean {
  const files = [
    join(getAgentDir(), "compact-ui.json"),
    join(cwd, CONFIG_DIR_NAME, "compact-ui.json"),
  ];
  for (const p of files) {
    if (!existsSync(p)) continue;
    try {
      const j = JSON.parse(readFileSync(p, "utf-8"));
      if (typeof j?.enabled === "boolean") return j.enabled;
    } catch {}
  }
  return true; // 默认开启
}

function saveEnabled(v: boolean) {
  const p = join(getAgentDir(), "compact-ui.json");
  let cur: any = {};
  if (existsSync(p)) {
    try { cur = JSON.parse(readFileSync(p, "utf-8")); } catch {}
  }
  writeFileSync(p, JSON.stringify({ ...cur, enabled: v }, null, 2));
}

// ---- 渲染辅助 ----
const textOut = (result: any): string => {
  const c = result?.content?.[0];
  return typeof c?.text === "string" ? c.text : "";
};

const bashExit = (out: string): number | null => {
  const m = out.match(/exit code: (\d+)/);
  return m ? parseInt(m[1], 10) : null;
};

const T = (theme: any) => ({
  bm: (s: string) => (theme.fg?.(`borderMuted`, s) ?? s),
  ac: (s: string) => (theme.fg?.(`accent`, s) ?? s),
  to: (s: string) => (theme.fg?.(`toolOutput`, s) ?? s),
  dm: (s: string) => (theme.fg?.(`dim`, s) ?? s),
  ok: (s: string) => (theme.fg?.(`success`, s) ?? s),
  er: (s: string) => (theme.fg?.(`error`, s) ?? s),
});

const callLine = (theme: any, kind: string, arg: string) => {
  const t = T(theme);
  const short = arg.length > 92 ? arg.slice(0, 89) + "…" : arg;
  return new Text(`${t.bm("╭─")} ${t.ac(kind)} ${t.to(short)}`, 0, 0);
};

const resLine = (theme: any, body: string, status?: [string, string]) => {
  const t = T(theme);
  const st = status ? `${(status[0] === "ok" ? t.ok : t.er)(status[1])} ` : "";
  return new Text(`${t.bm("╰─")} ${st}${t.dm(body)}`, 0, 0);
};

const genericRes = (kind: string) => (r: any, o: any, th: any) => {
  if (o.isPartial) return new Text("…", 0, 0);
  const out = textOut(r);
  if (o.expanded) return new Text(out, 0, 0);
  const first = out.split("\n").filter((l: string) => l.trim())[0] ?? "";
  const n = out.split("\n").filter((l: string) => l.trim()).length;
  const isErr = r?.isError || /^Error/i.test(out);
  return resLine(th, `${first}${n > 1 ? ` …(+${n - 1} lines)` : ""}`, isErr ? ["er", "err"] : ["ok", "ok"]);
};

export default function (pi: ExtensionAPI) {
  const localCwd = process.cwd();
  if (!loadEnabled(localCwd)) return;

  const origBash = createBashTool(localCwd);
  const origRead = createReadTool(localCwd);
  const origWrite = createWriteTool(localCwd);
  const origEdit = createEditTool(localCwd);
  const origFind = createFindTool(localCwd);
  const origGrep = createGrepTool(localCwd);
  const origLs = createLsTool(localCwd);

  const defs: any[] = [
    { name: "grep", orig: origGrep,
      call: (a: any, th: any) => callLine(th, "grep", `${a.pattern ?? ""} ${a.path ?? ""}`),
      res: genericRes("grep"), },
    { name: "find", orig: origFind,
      call: (a: any, th: any) => callLine(th, "find", `${a.pattern ?? ""} ${a.path ?? ""}`),
      res: genericRes("find"), },
    { name: "ls", orig: origLs,
      call: (a: any, th: any) => callLine(th, "ls", a.path ?? "."),
      res: genericRes("ls"), },
    { name: "bash", orig: origBash,
      call: (a: any, th: any) => callLine(th, "bash", a.command ?? ""),
      res: (r: any, o: any, th: any) => {
        if (o.isPartial) return new Text("…", 0, 0);
        const out = textOut(r);
        if (o.expanded) return new Text(out, 0, 0);
        const exit = bashExit(out);
        const body = out.split("\n").filter((l: string) => l.trim())[0] || "";
        const lines = out.split("\n").filter((l: string) => l.trim()).length;
        const code = exit === null ? (lines ? 0 : null) : exit;
        const st: [string, string] = code === 0 ? ["ok", "ok"] : ["er", `exit ${code ?? "?"}`];
        return resLine(th, `${body}${lines > 1 ? ` …(+${lines - 1} lines)` : ""}`, st);
      }, },
    { name: "read", orig: origRead,
      call: (a: any, th: any) => callLine(th, "read", a.path ?? ""),
      res: (r: any, o: any, th: any) => {
        if (o.isPartial) return new Text("…", 0, 0);
        const out = textOut(r);
        const n = out.split("\n").length;
        if (o.expanded) return new Text(out, 0, 0);
        return resLine(th, `${n} lines`, ["ok", "ok"]);
      }, },
    { name: "write", orig: origWrite,
      call: (a: any, th: any) => callLine(th, "write", `${a.path ?? ""} (${(a.content ?? "").split("\n").length}L)`),
      res: (r: any, o: any, th: any) => {
        if (o.isPartial) return new Text("…", 0, 0);
        const out = textOut(r);
        if (/^Error/i.test(out)) return resLine(th, out.split("\n")[0], ["er", "err"]);
        return resLine(th, "written", ["ok", "ok"]);
      }, },
    { name: "edit", orig: origEdit,
      call: (a: any, th: any) => callLine(th, "edit", a.path ?? ""),
      res: (r: any, o: any, th: any) => {
        if (o.isPartial) return new Text("…", 0, 0);
        const out = textOut(r);
        if (/^Error/i.test(out)) return resLine(th, out.split("\n")[0], ["er", "err"]);
        const d: any = r.details;
        const diff = d?.diff ?? "";
        const add = diff.split("\n").filter((l: string) => l.startsWith("+") && !l.startsWith("+++")).length;
        const del = diff.split("\n").filter((l: string) => l.startsWith("-") && !l.startsWith("---")).length;
        return resLine(th, `+${add}/-${del}`, ["ok", "ok"]);
      }, },
  ];

  for (const d of defs) {
    pi.registerTool({
      ...d.orig, name: d.name, renderShell: "self",
      async execute(id: any, p: any, s: any, u: any) { return d.orig.execute(id, p, s, u); },
      renderCall: d.call,
      renderResult: d.res,
    });
  }

  // ---- 命令: /compact-ui ----
  pi.registerCommand("compact-ui", {
    description: "紧凑渲染开关 (需 /reload 生效)",
    handler: async (args, ctx) => {
      const sub = (args || "").trim().toLowerCase();
      if (sub === "on" || sub === "enable") {
        saveEnabled(true);
        ctx.ui.notify("compact-ui: 紧凑渲染已开启 (需要 /reload 生效)", "info");
        return;
      }
      if (sub === "off" || sub === "disable") {
        saveEnabled(false);
        ctx.ui.notify("compact-ui: 紧凑渲染已关闭 (需要 /reload 生效)", "info");
        return;
      }
      ctx.ui.notify(`compact-ui: ${loadEnabled(ctx.cwd) ? "on" : "off"}  (命令: /compact-ui on|off, 需 /reload)`, "info");
    },
  });
}
