# pi-hunk-gate

LLM commit 前 review gate + hunk 注释桥。改动未经 review 时拦截 `git commit`，
agent 和用户通过 hunk 会话交换 inline 注释，用户批准后才放行。

依赖 [hunk](https://github.com/modem-dev/hunk) CLI（`mise use -g hunk`）。

## 工作流

1. **LLM 改完代码想 commit** → 被 gate 拦截，输出流程提示
2. **打开 hunk**：另一个终端跑 `hunk diff`（或 `/hunk open` 看提示）
3. **agent 加注释**：`hunk_comment_add`（单条或 `batch` 批量）
4. **用户看 diff + 注释**，按 `c` 写自己的 note
5. **agent 读反馈**：`hunk_comment_read --type user` 拿用户 note 处理
6. **用户批准**：`/hunk approve` → 同一改动集合的 `git commit` 放行

改动变了（diff hash 不同）自动重新锁定。

## LLM 工具

| 工具 | 作用 |
|---|---|
| `hunk_open` | 打开/确认 hunk 会话 |
| `hunk_comment_add` | agent 在 hunk 加 inline 注释 |
| `hunk_comment_read` | 读注释（`--type user` 读用户 note） |
| `hunk_status` | gate + 会话状态 |

## 用户命令

| 命令 | 作用 |
|---|---|
| `/hunk` | 状态 |
| `/hunk open [diff\|show X\|staged]` | 提示打开 hunk |
| `/hunk continue` | 读取用户 note 并交给 LLM 自动处理 |
| `/hunk approve` | 批准当前改动，解锁 commit，并自动通知 LLM 可以 commit |
| `/hunk block` | 重新锁定 |
| `/hunk notes [type]` | 列出注释 |

写完 note 回到 pi 后，输入 `/hunk continue` 即可让 LLM 读取并处理，不用手动解释。

## 状态

- gate 批准记录：`~/.pi/agent/hunk-gate.json`
- hunk 注释存在 hunk 会话里（用户 hunk 窗口），agent 通过 `hunk session` 读写
