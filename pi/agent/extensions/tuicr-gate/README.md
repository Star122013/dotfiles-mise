# pi-tuicr-gate

LLM commit 前 review gate + tuicr 注释桥。改动未经 review 时拦截 `git commit`，
agent 和用户通过在 tuicr 里交换 inline 注释，用户批准后才放行。

替代原有 `hunk-gate`:查看/批注从 [hunk](https://github.com/modem-dev/hunk) 换成
[tuicr](https://github.com/agavra/tuicr)(`mise use github:agavra/tuicr`)。

## 工作流

1. **LLM 改完代码想 commit** → 被 gate 拦截,输出流程提示
2. **打开 tuicr**:另一个终端跑 `tuicr -w`(未提交改动; 或直接 `tuicr` 选 commit 范围)
   → 生成一个 review session(slug 见 `tuicr review list`)
3. **agent 加注释**:`tuicr_comment_add`(单条或 `batch`),统一用
   `--type note` + `--username pi`
4. **用户看 diff + 注释**,在 tuicr 里按 `c` 写自己的评论
5. **agent 读反馈**:`tuicr_comment_read --type user` 拿用户 note 处理
   (用户 note = 非 `note` 类型的注释;`note` 类型留给 agent 专用)
6. **用户批准**:`/tuicr approve` → 同一改动集合的 `git commit` 放行

改动变了(diff hash 不同)自动重新锁定。

## LLM 工具

| 工具 | 作用 |
|---|---|
| `tuicr_open` | 打开/确认 tuicr review session, 报告 slug 与 gate 状态 |
| `tuicr_comment_add` | agent 在 tuicr 加 inline 注释(type=note) |
| `tuicr_comment_read` | 读注释(`--type user` 读用户 note) |
| `tuicr_status` | gate + session 状态 |

## 用户命令

| 命令 | 作用 |
|---|---|
| `/tuicr` | 状态 |
| `/tuicr open` | 提示打开 tuicr review |
| `/tuicr continue` | 读取用户 note 并交给 LLM 自动处理 |
| `/tuicr approve` | 批准当前改动,解锁 commit,自动通知 LLM 可以 commit |
| `/tuicr block` | 重新锁定 |
| `/tuicr notes [user]` | 列出注释 |

写完 note 回到 pi 后,输入 `/tuicr continue` 即可让 LLM 读取并处理,不用手动解释。

## 状态

- gate 批准记录:`~/.pi/agent/tuicr-gate.json`
- tuicr 注释存在 tuicr 的 review session 里(`~/.local/share/tuicr/reviews/`)
- agent 与用户注释靠 `comment_type` 区分:`note` = agent;其余 = 用户
  (`tuicr review comments` 的 JSON 不暴露 author,故用类型约定)