local M = {}

local pr_builder = require('pr')
local diff_layout = require('layout.diff')
local layout = require('layout')

M.current_diff_layout = nil
M.review_files = nil
M.review_pr = nil

local function set_qf_files(files, title)
	local items = {}
	for _, f in ipairs(files) do
		if f ~= "" then
			table.insert(items, { filename = f, lnum = 1, col = 1, text = "file" })
		end
	end
	vim.fn.setqflist({}, "r", { title = title or "files", items = items })
	vim.cmd("copen")
end


function M.diff(file, pr)
	if not pr then
		vim.notify("GhReview: PR context missing", vim.log.levels.ERROR)
		return
	end

	if not file or file == "" then
		vim.notify("GhReview: no file selected for diff", vim.log.levels.WARN)
		return
	end

	local diff_files, err = pr:get_file_diff(file)
	if not diff_files then
		vim.notify(err or ("GhReview: unable to diff " .. file), vim.log.levels.ERROR)
		return
	end


	M.update_diff(diff_files.base, diff_files.head, diff_files.type)
end

local function normalize_pr_id(pr_id)
	if type(pr_id) == "table" then
		return pr_id[1]
	end
	return pr_id
end

function M.review(pr_id)
	local normalized_id = normalize_pr_id(pr_id)

	local pr, err = pr_builder.new(normalized_id)
	if pr == nil then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	local files, files_err = pr:get_files_list()
	if files_err then
		vim.notify(files_err, vim.log.levels.ERROR)
		return
	end

	if vim.tbl_isempty(files) then
		vim.notify("GhReview: no files changed in this PR", vim.log.levels.INFO)
		return
	end

	M.review_files = files
	M.review_pr = pr

	set_qf_files(files, "pr review")

	vim.cmd("copen")
	local qf_win = vim.api.nvim_get_current_win()
	layout.map_iteration_keys(vim.api.nvim_win_get_buf(qf_win))
	vim.cmd("wincmd p")
	M.current_diff_layout = diff_layout.new()
	M.diff(files[2], pr)
end

return M
