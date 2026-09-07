---
name: tuicr-review
description: Use tuicr (a terminal code-review TUI) to review a diff and write inline line/file/review comments (批注) in the active review session, then read back the reviewer's notes. Use when you need to annotate a Git diff or send review feedback as line comments.
---

# tuicr-review

Write review comments and read reviewer notes through the
[tuicr](https://github.com/agavra/tuicr) review session store. tuicr keeps
persisted review sessions per repo; a session is created when the user opens the
tuicr TUI (`tuicr -w` for uncommitted changes, plain `tuicr` to pick a commit
range) in any terminal.

## Prerequisites

- tuicr CLI installed (`tuicr --version`) — via `mise use github:agavra/tuicr`.
- A review session must exist for the current repo: `tuicr review list --repo .`
  should return at least one entry. If it is empty, ask the user to open the TUI
  (`tuicr -w`) in another terminal first; a session is created when a review
  target becomes active.

## Author convention

`tuicr review comments` JSON does **not** expose the author field, so agent and
reviewer comments are distinguished by `comment_type`:

- **Agent-written** comments always use `comment_type = "note"` and
  `--username pi`.
- **Reviewer ("user") notes** are every comment whose type is NOT `note`
  (e.g. `issue`, `suggestion`, `none`, `praise`).

Use this to avoid confusing your own comments with the reviewer's feedback.

## Resolve the active session

```bash
tuicr review list --repo .   # JSON; prefer the entry with "active": true
```

Pick the active session slug (fall back to the most recent local entry). All
commands below take `--session <slug>`.

## Write a comment (批注)

Single line comment (new-file side by default):

```bash
tuicr review add --session <slug> --repo . \
  --type note --username pi \
  --target-file src/main.rs --line 42 --side new \
  "Handle the empty case here."
```

Line range:

```bash
tuicr review add --session <slug> --repo . \
  --type note --username pi \
  --target-file src/main.rs --line 10 --end-line 14 --side new \
  "This block could be simplified."
```

File-level (no `--line`), or review-level (no `--target-file`):

```bash
tuicr review add --session <slug> --repo . --type note --username pi \
  --target-file src/main.rs "Overall note for this file."
```

Structured JSON via stdin (works with newlines / unicode safely):

```bash
cat <<'JSON' | tuicr review add --session <slug> --repo . --username pi --input -
{"type":"note","content":"Here is the note.","file":"src/main.rs","line":42,"side":"new"}
JSON
```

JSON fields: `content` (required), `type`, `file`, `line`, `start_line` +
`end_line` (range), `side` (`old`|`new`, default `new`).

## Read comments / reviewer notes

All comments:

```bash
tuicr review comments --session <slug> --repo .
```

Only the reviewer's feedback (excludes your own `note` type):

```bash
tuicr review comments --session <slug> --repo . | \
  jq '[.[] | select(.comment_type != "note")]'
```

Each comment has: `path`, `start_line`/`end_line`, `side`, `comment_type`,
`content`, `lifecycle_state`.

## Guidance for the agent

- Prefer a few targeted line comments over dumping analysis in chat: the user
  reads them inline in the TUI.
- Always stamp `--username pi` and `--type note` so your comments stay visually
  and logically distinct from the reviewer's.
- After the reviewer writes notes and returns to pi, read them with
  `tuicr_comment_read --type user` (or the jq filter above) and act on each one.
- If there is no session yet, do not invent a slug — `review add` errors on
  unknown sessions. Ask for the TUI to be opened first.