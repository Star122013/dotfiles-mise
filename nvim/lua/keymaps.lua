vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

-- stylua: ignore start
vim.keymap.set("i", "<C-h>", "<Left>", { noremap = true, silent = true, desc = "Move Left" })
vim.keymap.set("i", "<C-j>", "<Down>", { noremap = true, silent = true, desc = "Move Down" })
vim.keymap.set("i", "<C-k>", "<Up>", { noremap = true, silent = true, desc = "Move Up" })
vim.keymap.set("i", "<C-l>", "<Right>", { noremap = true, silent = true, desc = "Move Right" })
vim.keymap.set("n", "<C-z>", "u", { noremap = true, silent = true, desc = "Undo" })

vim.keymap.set("n", "]t", "<Cmd>tabnext<CR>", { desc = "Next tab" })
vim.keymap.set("n", "[t", "<Cmd>tabprev<CR>", { desc = "Prev tab" })
vim.keymap.set("n", "<Leader>bd", "<Cmd>bdelete<CR>", { desc = "Buffer close" })
vim.keymap.set("n", "<Leader>td", "<Cmd>tabclose<CR>", { desc = "Tab close" })

vim.keymap.set("n", "<Leader>ff", function() MiniPick.builtin.files() end, { desc = "Find files" })
vim.keymap.set("n", "<Leader>fgl", function() MiniPick.builtin.grep_live() end, { desc = "Grep" })
vim.keymap.set("n", "<Leader>fbb", function() MiniPick.builtin.buffers() end, { desc = "Buffers" })
vim.keymap.set("n", "<Leader>fbl", function() MiniExtra.pickers.buf_lines() end, { desc = "Buffers lines" })
vim.keymap.set("n", "<Leader>fhh", function() MiniPick.builtin.help() end, { desc = "Help" })
vim.keymap.set("n", "<Leader>fc", function() MiniExtra.pickers.commands() end, { desc = "Commands" })
vim.keymap.set("n", "<Leader>fd", function() MiniExtra.pickers.diagnostic() end, { desc = "Diagnostics" })
vim.keymap.set("n", "<Leader>fht", function() MiniExtra.pickers.hipatterns() end, { desc = "Hippterns" })
vim.keymap.set("n", "<Leader>fhi", function() MiniExtra.pickers.history() end, { desc = "History" })
vim.keymap.set("n", "<Leader>fk", function() MiniExtra.pickers.keymaps() end, { desc = "Keymaps" })
vim.keymap.set("n", "<Leader>fq", function() MiniExtra.pickers.list({ scope = 'quickfix' }) end, { desc = "Quickfix" })
vim.keymap.set("n", "<Leader>fm", function() MiniExtra.pickers.manpages() end, { desc = "Manpages" })

vim.keymap.set("n", "<Leader>gb", function() MiniExtra.pickers.git_branches() end, { desc = "Git branches" })
vim.keymap.set("n", "<Leader>gc", function() MiniExtra.pickers.git_commits() end, { desc = "Git commits" })
vim.keymap.set("n", "<Leader>gf", function() MiniExtra.pickers.git_files() end, { desc = "Git files" })
vim.keymap.set("n", "<Leader>gh", function() MiniExtra.pickers.git_hunks() end, { desc = "Git hunks" })

vim.keymap.set("n", "<Leader>gd", function() MiniExtra.pickers.lsp({ scope = 'definition' }) end, { desc = "LSP definition" })
vim.keymap.set("n", "<Leader>gD", function() MiniExtra.pickers.lsp({ scope = 'declaration' }) end, { desc = "LSP declaration" })
vim.keymap.set("n", "<Leader>gr", function() MiniExtra.pickers.lsp({ scope = 'references' }) end, { desc = "LSP references" })
vim.keymap.set("n", "<Leader>gI", function() MiniExtra.pickers.lsp({ scope = 'implementation' }) end, { desc = "LSP implementation" })
vim.keymap.set("n", "<Leader>gt", function() MiniExtra.pickers.lsp({ scope = 'type_definition' }) end, { desc = "LSP type definition" })
vim.keymap.set("n", "<Leader>gs", function() MiniExtra.pickers.lsp({ scope = 'document_symbol' }) end, { desc = "LSP document symbols" })
vim.keymap.set("n", "<Leader>gW", function() MiniExtra.pickers.lsp({ scope = 'workspace_symbol' }) end, { desc = "LSP workspace symbols" })
vim.keymap.set("n", "<Leader>gw", function() MiniExtra.pickers.lsp({ scope = 'workspace_symbol_live' }) end, { desc = "LSP workspace symbols (live)" })

vim.keymap.set("n", "<Leader>jj", function() MiniJump2d.start(MiniJump2d.builtin_opts.single_character) end, { desc = "Jump2d char" })
vim.keymap.set("n", "<Leader>jw", function() MiniJump2d.start(MiniJump2d.builtin_opts.word_start) end, { desc = "Jump2d word" })
vim.keymap.set("n", "<Leader>jl", function() MiniJump2d.start(MiniJump2d.builtin_opts.line_start) end, { desc = "Jump2d line" })
vim.keymap.set("n", "<Leader>js", function() MiniJump2d.start(MiniJump2d.builtin_opts.query) end, { desc = "Jump2d search" })

vim.keymap.set("n", "<Leader>fe", function() require("mini.files").open() end, { desc = "Explorer (mini.files)" })
vim.keymap.set("n", "<Leader>fH", function() require("mini.files").open(vim.fn.expand "~") end, { desc = "Explorer (mini.files) home" })

vim.keymap.set({ "n", "x" }, "<leader>ap", function() require("sidekick.cli").prompt() end, { desc = "Sidekick prompt…" })
vim.keymap.set({ "n", "x" }, "<leader>as", function() require("sidekick.cli").select() end, { desc = "Sidekick select CLI" })
vim.keymap.set({ "n", "t" }, "<c-.>", function() require("sidekick.cli").focus() end, { desc = "Sidekick focus" })
vim.keymap.set("n", "<leader>aa", function() require("sidekick.cli").toggle() end, { desc = "Sidekick toggle CLI" })

vim.keymap.set({ "n", "x" }, "<Leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
-- You may want these if you use the opinionated `<C-a>` and `<C-x>` keymaps above — otherwise consider `<leader>o…` (and remove terminal mode from the `toggle` keymap)
vim.keymap.set("n", "+", "<C-a>", { desc = "Increment under cursor", noremap = true })
vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement under cursor", noremap = true })
