# pi-toolbox

podman 轻量沙箱。pi 留 host，任务按语言镜像分发。

## 镜像 (一个语言一个镜像)

- `pi-toolbox:slim` (561MB) - 基础: typst + graphviz + pandoc-cli + imagemagick + fonts
- `pi-toolbox:python` (1.09GB) - slim + python3 + uv/ruff
- `pi-toolbox:node` (~600MB) - slim + nodejs + mermaid-cli
- `pi-toolbox:go` (~600MB) - slim + go
- `pi-toolbox:zig` (1.07GB) - slim + zig 0.16 (拖 llvm)
- `pi-toolbox:rust` (~1.2GB) - slim + rust/cargo
- `pi-toolbox:ruby` (~600MB) - slim + ruby

按需构建，不用全装。`pi-toolbox:fat` (旧 3.66GB 全家桶) 保留为 Dockerfile.fat。

## 构建

```bash
/toolbox build          # pi-toolbox:slim (默认)
/toolbox build python   # pi-toolbox:python
/toolbox build zig      # pi-toolbox:zig
/toolbox build node/go/rust/ruby
podman images | grep pi-toolbox
```

Dockerfile 在 `~/.pi/agent/extensions/toolbox/`，语言镜像在 `langs/Dockerfile.*`

## 工具

- `toolbox_exec(command, image?)` - 指定镜像执行，默认 `pi-toolbox:slim`
  - `toolbox_exec(command="python3 app.py", image="pi-toolbox:python")`
  - `toolbox_exec(command="zig build run", image="pi-toolbox:zig")`
- `math_render(source)` - typst 公式，自动用 `ghcr.io/typst/typst` 或 slim

## 命令

- `/toolbox` - 状态
- `/toolbox on|off` - bash 自动路由开关
- `/toolbox test` - 自检
