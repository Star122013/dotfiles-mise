/**
 * pi-toolbox - podman 通用沙箱 + typst 数学公式工具箱 (功能部分)
 *
 * pi 留在 host，任务丢进 podman 容器。支持：
 * - toolbox_exec: 任意命令在容器里跑 (alpine/pi-toolbox)
 * - math_render: typst 公式渲染为 PNG (ghcr.io/typst/typst 或 pi-toolbox)
 * - 可选的 bash 路由: 拦截内置 bash 工具，自动用 podman 包一层
 *
 * 纯功能插件，不含任何 UI 渲染 (紧凑细线风格在独立插件 compact-ui)。
 *
 * 配置 (优先级: 项目 > 全局 > 默认):
 * - ~/.pi/agent/toolbox.json
 * - .pi/toolbox.json
 * {
 *   "image": "pi-toolbox:latest",          // 通用任务镜像 (fallback alpine:latest)
 *   "mathImage": "pi-toolbox:slim",                // 自带 typst + Noto CJK 字体
 *   "network": "pasta",                     // none | host | pasta | bridge
 *   "routeBash": false,                     // true 则所有 bash 自动走容器
 *   "verbose": false
 * }
 *
 * 命令:
 * - /toolbox              状态
 * - /toolbox on|off       切换 bash 路由
 * - /toolbox build        podman build -t pi-toolbox -f Dockerfile .
 * - /toolbox test         自检 (alpine echo + typst 渲染)
 */

import { spawn, execSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { readFile, writeFile } from "node:fs/promises";
import { join, relative, resolve } from "node:path";
import { tmpdir } from "node:os";
import { randomBytes } from "node:crypto";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { CONFIG_DIR_NAME, getAgentDir } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { Text } from "@earendil-works/pi-tui";

interface ToolboxConfig {
  image?: string;
  mathImage?: string;
  network?: string;
  routeBash?: boolean;
  verbose?: boolean;
}

const DEFAULT_CONFIG: Required<ToolboxConfig> = {
  image: "pi-toolbox:slim",
  mathImage: "pi-toolbox:slim",
  network: "pasta",
  routeBash: false,
  verbose: false,
};

function loadConfig(cwd: string): Required<ToolboxConfig> {
  const globalPath = join(getAgentDir(), "toolbox.json");
  const projectPath = join(cwd, CONFIG_DIR_NAME, "toolbox.json");
  // 兼容旧位: extension 目录下的 config
  const extPath = join(getAgentDir(), "extensions", "toolbox", "toolbox.json");
  let cfg: ToolboxConfig = { ...DEFAULT_CONFIG };
  for (const p of [globalPath, extPath, projectPath]) {
    if (!existsSync(p)) continue;
    try {
      const j = JSON.parse(readFileSync(p, "utf-8"));
      cfg = { ...cfg, ...j };
    } catch {}
  }
  // env 覆盖
  if (process.env.PI_TOOLBOX_IMAGE) cfg.image = process.env.PI_TOOLBOX_IMAGE;
  if (process.env.PI_TOOLBOX_MATH_IMAGE) cfg.mathImage = process.env.PI_TOOLBOX_MATH_IMAGE;
  return cfg as Required<ToolboxConfig>;
}

function saveGlobalConfig(patch: Partial<ToolboxConfig>) {
  const p = join(getAgentDir(), "toolbox.json");
  let cur: ToolboxConfig = {};
  if (existsSync(p)) {
    try { cur = JSON.parse(readFileSync(p, "utf-8")); } catch {}
  }
  const next = { ...cur, ...patch };
  writeFileSync(p, JSON.stringify(next, null, 2));
}

function hasPodman(): boolean {
  try { execSync("podman --version", { stdio: "ignore" }); return true; } catch { return false; }
}

function imageExists(image: string): boolean {
  try { execSync(`podman image exists ${image}`, { stdio: "ignore" }); return true; } catch { return false; }
}

function shellEscape(s: string): string {
  return `'${s.replace(/'/g, `'\\''`)}'`;
}

function toContainerCwd(hostCwd: string, localCwd: string): string {
  // 映射 host cwd 到容器内工作目录
  const absCwd = resolve(hostCwd);
  const absLocal = resolve(localCwd);
  const rel = relative(absLocal, absCwd);
  if (rel === "" || (!rel.startsWith("..") && !rel.includes(".."))) {
    return rel ? `/workspace/${rel}` : "/workspace";
  }
  if (absCwd.startsWith("/tmp")) return absCwd; // /tmp 直通
  return "/workspace";
}

function buildPodmanArgs(opts: {
  image: string;
  localCwd: string;
  hostCwd: string;
  network: string;
}): string[] {
  const cCwd = toContainerCwd(opts.hostCwd, opts.localCwd);
  const args = ["run", "--rm",
    "-v", `${opts.localCwd}:/workspace:z`,
    "-v", "/tmp:/tmp:z",
    "-w", cCwd,
  ];
  if (opts.network && opts.network !== "host") {
    args.push("--network", opts.network);
  } else if (opts.network === "host") {
    args.push("--network", "host");
  }
  // 只读挂载 host 家目录防护 (可选)
  args.push(opts.image);
  return args;
}

async function podmanExec(
  command: string,
  opts: { image: string; localCwd: string; hostCwd: string; network: string; onData?: (d: string) => void; signal?: AbortSignal; timeout?: number }
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  const args = buildPodmanArgs({ image: opts.image, localCwd: opts.localCwd, hostCwd: opts.hostCwd, network: opts.network });
  // 用 sh -lc 执行原始命令
  const fullArgs = [...args, "sh", "-lc", command];

  return new Promise((resolve, reject) => {
    const child = spawn("podman", fullArgs, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    if (opts.timeout && opts.timeout > 0) {
      timer = setTimeout(() => { timedOut = true; child.kill("SIGKILL"); }, opts.timeout * 1000);
    }
    opts.signal?.addEventListener("abort", () => child.kill("SIGTERM"), { once: true });
    child.stdout.on("data", (d: Buffer) => { const s = d.toString(); stdout += s; opts.onData?.(s); });
    child.stderr.on("data", (d: Buffer) => { const s = d.toString(); stderr += s; opts.onData?.(s); });
    child.on("error", (e) => { if (timer) clearTimeout(timer); reject(e); });
    child.on("close", (code) => {
      if (timer) clearTimeout(timer);
      if (timedOut) return reject(new Error(`podman timeout ${opts.timeout}s\n${stderr}`));
      if (opts.signal?.aborted) return reject(new Error("aborted"));
      resolve({ stdout, stderr, exitCode: code ?? 0 });
    });
  });
}

// typst 渲染: 优先容器, 回退 host
async function renderTypstToPng(source: string, localCwd: string, cfg: Required<ToolboxConfig>, signal?: AbortSignal): Promise<{ pngPath: string; b64: string; used: string }> {
  const id = randomBytes(4).toString("hex");
  const typPath = join(tmpdir(), `pi-math-${id}.typ`);
  const pngPath = join(tmpdir(), `pi-math-${id}.png`);
  const content = `#set page(width: auto, height: auto, margin: 8pt)\n#set text(size: 14pt)\n$ ${source} $`;
  await writeFile(typPath, content, "utf-8");

  const tryImages = [cfg.mathImage, cfg.image, "ghcr.io/typst/typst:latest"];
  let lastErr = "";
  // typst 官方镜像 entrypoint 就是 typst, 不能用 sh -lc; 需直接 podman run ... compile
  async function tryPodmanTypst(img: string): Promise<boolean> {
    const isTypstImage = img.includes("typst/typst") || img.includes("typst:");
    if (isTypstImage) {
      // 直接调用: podman run --rm -v /tmp:/tmp:z --network none IMAGE compile SRC DST
      const args = ["run", "--rm", "-v", "/tmp:/tmp:z", "--network", "none", img, "compile", typPath, pngPath];
      const r = await new Promise<{ stdout: string; stderr: string; exitCode: number }>((resolve, reject) => {
        const child = spawn("podman", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = "", er = "";
        child.stdout.on("data", (d: Buffer) => out += d.toString());
        child.stderr.on("data", (d: Buffer) => er += d.toString());
        child.on("close", (code) => resolve({ stdout: out, stderr: er, exitCode: code ?? 0 }));
        child.on("error", reject);
        signal?.addEventListener("abort", () => child.kill("SIGTERM"), { once: true });
      });
      if (r.exitCode === 0 && existsSync(pngPath)) return true;
      lastErr = r.stderr || r.stdout;
      return false;
    } else {
      const cmd = `typst compile ${shellEscape(typPath)} ${shellEscape(pngPath)}`;
      const r = await podmanExec(cmd, { image: img, localCwd, hostCwd: tmpdir(), network: "none", signal });
      if (r.exitCode === 0 && existsSync(pngPath)) return true;
      lastErr = r.stderr || r.stdout;
      return false;
    }
  }
  for (const img of tryImages) {
    if (!img) continue;
    try {
      if (hasPodman()) {
        if (await tryPodmanTypst(img)) {
          const b64 = await readFile(pngPath, "base64");
          return { pngPath, b64, used: `podman:${img}` };
        }
      }
    } catch (e: any) { lastErr = e.message; }
  }
  // 回退 host typst
  try {
    execSync(`typst compile ${shellEscape(typPath)} ${shellEscape(pngPath)}`, { stdio: "pipe" });
    if (existsSync(pngPath)) {
      const b64 = await readFile(pngPath, "base64");
      return { pngPath, b64, used: "host:typst" };
    }
  } catch (e: any) { lastErr = e.message + "\n" + lastErr; }
  throw new Error(`typst 渲染失败: ${lastErr}`);
}

export default function (pi: ExtensionAPI) {
  const localCwd = process.cwd();
  let cfg = loadConfig(localCwd);

  pi.registerTool({
    name: "toolbox_exec",
    label: "Toolbox Exec",
    description: "在 podman 容器内执行任意命令 (沙箱, /workspace 透传)。用于运行不可信/重型任务、需要隔离环境的计算。优先用此工具而非 host bash。",
    parameters: Type.Object({
      command: Type.String({ description: "shell 命令, 在容器内 /workspace 下执行" }),
      image: Type.Optional(Type.String({ description: "覆盖默认镜像, 如 alpine:latest 或 pi-toolbox:latest" })),
      timeout: Type.Optional(Type.Number({ description: "超时秒, 默认 60" })),
      network: Type.Optional(Type.String({ description: "网络模式: none/host/pasta, 默认 none" })),
    }),
    async execute(toolCallId, params, signal, onUpdate) {
      const image = params.image || cfg.image;
      const network = params.network || cfg.network;
      const timeout = params.timeout ?? 60;

      // 自动 pull 缺失镜像 (后台)
      if (hasPodman() && !imageExists(image)) {
        onUpdate({ content: [{ type: "text", text: `pulling ${image} ...` }] } as any);
        try { execSync(`podman pull ${image}`, { stdio: "pipe", timeout: 120_000 }); } catch {}
      }
      if (!hasPodman()) {
        return { content: [{ type: "text", text: "podman 不可用, 回退到 host bash" }], details: { fallback: true } };
      }
      try {
        const r = await podmanExec(params.command, {
          image, localCwd, hostCwd: localCwd, network,
          signal: signal as any, timeout,
          onData: (d) => onUpdate({ content: [{ type: "text", text: d }] } as any),
        });
        const out = (r.stdout + (r.stderr ? "\n[stderr]\n" + r.stderr : "")).trim() || "(no output)";
        return {
          content: [{ type: "text", text: out.slice(0, 100_000) }],
          details: { exitCode: r.exitCode, image, network, isError: r.exitCode !== 0 },
        };
      } catch (e: any) {
        return { content: [{ type: "text", text: `toolbox_exec 失败: ${e.message}` }], details: { isError: true } };
      }
    },
  });

  // ---- 工具: math_render (typst 公式 -> 图片) ----
  pi.registerTool({
    name: "math_render",
    label: "Math Render",
    description: "用 typst 将 LaTeX/typst 数学公式渲染为 PNG 图片 (podman 沙箱内执行, 支持 Kitty/iTerm2 图片协议回显)。参数 source 为公式本体, 如 'sum_(k=1)^n k = (n(n+1))/2' 或 'E = m c^2'。优先用此工具展示数学公式。",
    parameters: Type.Object({
      source: Type.String({ description: "typst 数学公式源码, 不含 $ 包裹, 如 \\int_0^1 x^2 dif x" }),
      preamble: Type.Optional(Type.String({ description: "可选 typst 前导代码, 如 #set text(fill: red)" })),
    }),
    async execute(toolCallId, params, signal, onUpdate) {
      onUpdate({ content: [{ type: "text", text: "typst 渲染中..." }] } as any);
      try {
        const src = params.preamble ? `${params.preamble}\n${params.source}` : params.source;
        const { pngPath, b64, used } = await renderTypstToPng(src, localCwd, cfg, signal as any);
        // 返回 image content block: pi 会用自家 Image+fallbackColor 渲染 (Ghostty/Kitty 直显)
        return {
          content: [
            { type: "image", data: b64, mimeType: "image/png" },
            { type: "text", text: `rendered via ${used} -> ${pngPath}` },
          ],
          details: { pngPath, b64, mime: "image/png", used },
        };
      } catch (e: any) {
        // 出错也返回合法文本 content, 避免 details 缺失时 undefined
        return { content: [{ type: "text", text: `渲染失败: ${e.message}` }], details: { isError: true, error: String(e?.message ?? e) } };
      }
    },
    // 永远返回合法 Component (绝不 undefined)，否则 pi 会 addChild(undefined) 崩溃
    renderResult(result, _opts, theme) {
      const d: any = (result as any).details;
      let line: string;
      if (d?.isError) line = `渲染失败: ${d.error ?? "unknown"}`;
      else if (d?.pngPath) line = `${d.pngPath} via ${d.used ?? ""}${d.b64 ? ` ${Math.round(d.b64.length/1024)}KB` : ""}`;
      else line = `formula rendered (${d?.pngPath ?? ""})`.trim();
      try { return new Text((theme as any).fg?.("success", line) ?? line, 0, 0); } catch { return new Text(line, 0, 0); }
    },
  });

  // ---- 可选: 拦截 bash 自动走容器 ----
  pi.on("tool_call", async (event, ctx) => {
    cfg = loadConfig(ctx.cwd);
    if (!cfg.routeBash) return;
    if ((event as any).toolName !== "bash") return;
    if (!hasPodman()) return;
    const input: any = (event as any).input;
    if (!input?.command) return;
    const orig = input.command as string;
    // 已是 podman 命令则不重复包裹
    if (orig.trimStart().startsWith("podman ")) return;
    const image = cfg.image;
    const network = cfg.network;
    const cCwd = toContainerCwd(ctx.cwd, localCwd);
    // 构造 podman 包裹命令, 仍由 host bash 工具执行
    const wrapped = `podman run --rm --network ${network} -v ${shellEscape(localCwd)}:/workspace:z -v /tmp:/tmp:z -w ${shellEscape(cCwd)} ${image} sh -lc ${shellEscape(orig)}`;
    if (cfg.verbose) ctx.ui.notify(`toolbox route: ${orig.slice(0,60)}...`, "info");
    input.command = wrapped;
  });

  // ---- 命令: /toolbox ----
  pi.registerCommand("toolbox", {
    description: "工具箱控制 (podman 沙箱 + typst)",
    handler: async (args, ctx) => {
      cfg = loadConfig(ctx.cwd);
      const sub = (args || "").trim().toLowerCase();
      if (sub === "on" || sub === "enable") {
        saveGlobalConfig({ routeBash: true });
        cfg.routeBash = true;
        ctx.ui.notify("toolbox: bash 路由已开启 (所有 bash 走 podman)", "info");
        return;
      }
      if (sub === "off" || sub === "disable") {
        saveGlobalConfig({ routeBash: false });
        cfg.routeBash = false;
        ctx.ui.notify("toolbox: bash 路由已关闭", "info");
        return;
      }
      if (sub.startsWith("build")) {
        const parts = sub.split(/\s+/);
        const lang = parts[1] || "slim"; // slim | python | node | go | zig | rust | ruby | fat
        const tag = `pi-toolbox:${lang}`;
        const extDir = join(getAgentDir(), "extensions", "toolbox");
        let dockerfile = join(extDir, "Dockerfile");
        if (lang !== "slim" && lang !== "latest") {
          const cand1 = join(extDir, `Dockerfile.${lang}`);
          const cand2 = join(extDir, "langs", `Dockerfile.${lang}`);
          if (existsSync(cand2)) dockerfile = cand2;
          else if (existsSync(cand1)) dockerfile = cand1;
          else if (lang === "fat") dockerfile = join(extDir, "Dockerfile.fat");
        } else if (lang === "slim") {
          dockerfile = join(extDir, "Dockerfile");
        }
        ctx.ui.notify(`building ${tag} from ${dockerfile} ...`, "info");
        try {
          execSync(`podman build -t ${tag} -f ${dockerfile} ${extDir}`, { stdio: "inherit" });
          ctx.ui.notify(`build 完成: ${tag}`, "info");
        } catch (e: any) {
          ctx.ui.notify(`build 失败: ${e.message}`, "error");
        }
        return;
      }
      if (sub === "test") {
        const checks: string[] = [];
        checks.push(`podman: ${hasPodman() ? "ok " + execSync("podman --version").toString().trim() : "not found"}`);
        checks.push(`image ${cfg.image}: ${imageExists(cfg.image) ? "exists" : "missing (will pull)"}`);
        checks.push(`mathImage ${cfg.mathImage}: ${imageExists(cfg.mathImage) ? "exists" : "missing"}`);
        checks.push(`routeBash: ${cfg.routeBash ? "on" : "off"}  network: ${cfg.network}`);
        // 实际跑两个命令
        try {
          const r1 = await podmanExec("echo toolbox-ok && cat /etc/os-release | head -1", { image: "alpine:latest", localCwd, hostCwd: localCwd, network: "none" });
          checks.push(`alpine exec: ${r1.exitCode === 0 ? "ok" : "fail"} - ${r1.stdout.trim().slice(0,80)}`);
        } catch (e: any) { checks.push(`alpine exec: fail ${e.message.slice(0,80)}`); }
        try {
          const { used } = await renderTypstToPng("a^2 + b^2 = c^2", localCwd, cfg);
          checks.push(`typst: ok via ${used}`);
        } catch (e: any) { checks.push(`typst: fail ${e.message.slice(0,100)}`); }
        ctx.ui.notify(checks.join("\n"), "info");
        return;
      }
      // status
      const lines = [
        `toolbox status:`,
        `  podman: ${hasPodman() ? "yes" : "no"}`,
        `  image: ${cfg.image} (${imageExists(cfg.image) ? "exists" : "missing"})`,
        `  mathImage: ${cfg.mathImage} (${imageExists(cfg.mathImage) ? "exists" : "missing"})`,
        `  network: ${cfg.network}  routeBash: ${cfg.routeBash ? "on" : "off"}`,
        `  cwd: ${ctx.cwd} -> /workspace`,
        ``,
        `用法:`,
        `  /toolbox on|off          切换 bash 自动进容器`,
        `  /toolbox build [lang]    构建 pi-toolbox:slim (默认) 或指定语言: python/node/go/zig/rust/ruby/fat`,
        `    e.g. /toolbox build python -> pi-toolbox:python (1.09GB)`,
        `         /toolbox build zig    -> pi-toolbox:zig (1.07GB)`,
        `  /toolbox test            自检`,
        `  toolbox_exec / math_render  (LLM 工具)`,
      ];
      ctx.ui.notify(lines.join("\n"), "info");
    },
  });

  pi.on("session_start", async (_e, ctx) => {
    cfg = loadConfig(ctx.cwd);
    if (cfg.verbose) ctx.ui.notify(`toolbox ready: podman=${hasPodman()} routeBash=${cfg.routeBash}`, "info");
  });
}
