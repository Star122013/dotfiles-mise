-- TODO: config
require('mini.pick').setup()
require('mini.extra').setup()
require('mini.files').setup()
require('mini.jump').setup()
require('mini.jump2d').setup()
-- mini.diff
require('mini.diff').setup {
  view = {
    style = 'sign',
    signs = { add = '│', change = '│', delete = '│' },
  },
}
vim.keymap.set('n', '<Leader>go', function()
  MiniDiff.toggle_overlay()
end, { desc = 'Diff overlay' })

-- neogit
require('neogit').setup()
vim.keymap.set('n', '<Leader>gg', function()
  require('neogit').open()
end, { desc = 'Neogit' })

-- codediff.nvim
require('codediff').setup()
vim.keymap.set('n', '<Leader>gv', '<Cmd>CodeDiff<CR>', { desc = 'CodeDiff' })

-- mini.clue
local miniclue = require 'mini.clue'
miniclue.setup {
  triggers = {
    -- Leader triggers
    { mode = { 'n', 'x' }, keys = '<Leader>' },

    -- `[` and `]` keys
    { mode = 'n', keys = '[' },
    { mode = 'n', keys = ']' },

    -- Built-in completion
    { mode = 'i', keys = '<C-x>' },

    -- `g` key
    { mode = { 'n', 'x' }, keys = 'g' },

    -- Marks
    { mode = { 'n', 'x' }, keys = "'" },
    { mode = { 'n', 'x' }, keys = '`' },

    -- Registers
    { mode = { 'n', 'x' }, keys = '"' },
    { mode = { 'i', 'c' }, keys = '<C-r>' },

    -- Window commands
    { mode = 'n', keys = '<C-w>' },

    -- `z` key
    { mode = { 'n', 'x' }, keys = 'z' },

    -- Jump2d
    { mode = 'n', keys = '<Leader>j' },
  },

  clues = {
    -- Enhance this by adding descriptions for <Leader> mapping groups
    miniclue.gen_clues.square_brackets(),
    miniclue.gen_clues.builtin_completion(),
    miniclue.gen_clues.g(),
    miniclue.gen_clues.marks(),
    miniclue.gen_clues.registers(),
    miniclue.gen_clues.windows(),
    miniclue.gen_clues.z(),

    -- <Leader>g group
    { mode = 'n', keys = '<Leader>g', desc = '+goto/git' },
  },
}

-- mini.hipatterns
local hipatterns = require 'mini.hipatterns'
hipatterns.setup {
  highlighters = {
    -- Highlight standalone 'FIXME', 'HACK', 'TODO', 'NOTE'
    fixme = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
    hack = { pattern = '%f[%w]()HACK()%f[%W]', group = 'MiniHipatternsHack' },
    todo = { pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' },
    note = { pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' },

    -- Highlight hex color strings (`#rrggbb`) using that color
    hex_color = hipatterns.gen_highlighter.hex_color(),
  },
}
