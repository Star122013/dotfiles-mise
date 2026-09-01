-- plugins/format.lua — 纯外部命令格式化
-- 按文件类型调用外部命令，stdin 传入，stdout 替换 buffer

local formatters = {
	lua = { "stylua", "--search-parent-directories", "-" },
	nix = { "nixfmt" },
	go = { "gofmt" },
	rust = { "rustfmt" },
	zig = { "zig", "fmt", "--stdin" },
	c = { "clang-format" },
	cpp = { "clang-format" },
	json = { "jq", "." },
	html = { "tidy", "-indent", "-quiet", "--tidy-mark", "no" },
	yaml = { "yamlfmt" },
	python = { "ruff", "format", "-" },
	markdown = { "prettier", "--parser", "markdown" },
	typescript = { "prettier", "--parser", "typescript" },
	javascript = { "prettier", "--parser", "babel" },
	css = { "prettier", "--parser", "css" },
}

local function format()
	if vim.bo.buftype ~= "" then
		return
	end

	local spec = formatters[vim.bo.filetype]
	if not spec or vim.fn.executable(spec[1]) ~= 1 then
		return
	end

	local view = vim.fn.winsaveview()
	local input = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
	local result = vim.system({ spec[1], unpack(spec, 2) }, { stdin = input }):wait()

	if result.code == 0 then
		local lines = vim.split(result.stdout, "\n", { plain = true })
		if lines[#lines] == "" then
			table.remove(lines)
		end
		vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	end

	vim.fn.winrestview(view)
end

vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = "*",
	callback = format,
})

vim.keymap.set({ "n", "x" }, "<Leader>F", format, { desc = "Format buffer" })
