--=============================================================================
-- Theme
--=============================================================================
-- Palette source, in order of preference:
--   1. noctalia wallpaper theme — rendered to ~/.config/nvim/lua/matugen.lua
--      (outside the git repo; plain base16 palette table, recolors on wallpaper
--      change).
--   2. static snapshot in this repo (nvim/base16-colors.lua)
local config_dir = vim.fn.stdpath("config")
local function load_palette()
	local matugen_path = config_dir .. "/lua/matugen.lua"
	if vim.fn.filereadable(matugen_path) == 1 then
		local ok, palette = pcall(dofile, matugen_path)
		if ok and type(palette) == "table" then
			return palette
		end
	end
	return dofile(config_dir .. "/base16-colors.lua")
end

local c = load_palette()

--=============================================================================
-- mini.base16 — base16 color scheme using Stylix palette
--=============================================================================
require("mini.base16").setup({ palette = c })

-- Re-apply the palette when noctalia's neovim template sends SIGUSR1
-- (wallpaper changed).
vim.api.nvim_create_autocmd("Signal", {
	pattern = "SIGUSR1",
	callback = function()
		local fresh = load_palette()
		require("mini.base16").setup({ palette = fresh })
	end,
})

-- Transparent backgrounds
local set_hl = function(name, opts)
	vim.api.nvim_set_hl(0, name, opts)
end

set_hl("Normal", { bg = "NONE" })
set_hl("NonText", { bg = "NONE" })
set_hl("LineNr", { bg = "NONE" })
set_hl("LineNrAbove", { bg = "NONE" })
set_hl("LineNrBelow", { bg = "NONE" })
set_hl("SignColumn", { bg = "NONE" })
set_hl("NormalFloat", { bg = "NONE" })
set_hl("FloatBorder", { bg = "NONE" })

-- Re-apply transparency if colorscheme is reloaded
vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("stylix_transparent", { clear = true }),
	pattern = "*",
	callback = function()
		set_hl("Normal", { bg = "NONE" })
		set_hl("NonText", { bg = "NONE" })
		set_hl("LineNr", { bg = "NONE" })
		set_hl("LineNrAbove", { bg = "NONE" })
		set_hl("LineNrBelow", { bg = "NONE" })
		set_hl("SignColumn", { bg = "NONE" })
		set_hl("NormalFloat", { bg = "NONE" })
		set_hl("FloatBorder", { bg = "NONE" })
	end,
})

require("mini.tabline").setup()
require("mini.notify").setup()
require("mini.statusline").setup({
	content = {
		active = function()
			local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 120 })
			local git = MiniStatusline.section_git({ trunc_width = 40 })
			local diff = MiniStatusline.section_diff({ trunc_width = 75 })
			local diagnostics = MiniStatusline.section_diagnostics({ trunc_width = 75 })
			local lsp = MiniStatusline.section_lsp({ trunc_width = 75 })
			local filename = MiniStatusline.section_filename({ trunc_width = 140 })
			local fileinfo = MiniStatusline.section_fileinfo({ trunc_width = 120 })
			local location = MiniStatusline.section_location({ trunc_width = 75 })
			local search = MiniStatusline.section_searchcount({ trunc_width = 75 })

			return MiniStatusline.combine_groups({
				{ hl = mode_hl, strings = { mode } },
				{ hl = "MiniStatuslineDevinfo", strings = { git, diff } },
				"%<", -- Mark general truncate point
				{ hl = "MiniStatuslineFilename", strings = { filename } },
				"%=", -- End left alignment
				{ hl = "MiniStatuslineDevinfo", strings = { diagnostics, lsp } },
				{ hl = "MiniStatuslineFileinfo", strings = { fileinfo } },
				{ hl = mode_hl, strings = { search, location } },
			})
		end,
		inactive = nil,
	},
})
