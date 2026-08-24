--=============================================================================
-- Theme
--=============================================================================
-- Load static base16 colors (snapshot of former Stylix kanagawa-dragon palette,
-- lives in this repo at nvim/base16-colors.lua)
local c = dofile(vim.fn.stdpath("config") .. "/base16-colors.lua")

--=============================================================================
-- mini.base16 — base16 color scheme using Stylix palette
--=============================================================================
require("mini.base16").setup({ palette = c })

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
