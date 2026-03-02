local M = {}

local pr_builder = require('pr')
local layout = require('layout')

---@param file_name		string
---@param pr			Pr
---@param diff_layout	DiffLayout
function M.diff(file_name, pr, diff_layout)
	if not pr then
		vim.notify("GhReview: PR context missing", vim.log.levels.ERROR)
		return
	end

	if not file_name or file_name == "" then
		vim.notify("GhReview: no file_name selected for diff", vim.log.levels.WARN)
		return
	end

	local diff_files, err = pr:get_file_diff(file_name)
	if not diff_files then
		vim.notify(err or ("GhReview: unable to diff " .. file_name), vim.log.levels.ERROR)
		return
	end


	diff_layout:update(diff_files.base, diff_files.head, diff_files.type)
	layout.qflist.map_diff_layout_buffers(diff_layout, layout.qflist.forward, layout.qflist.backward)
end

---@return integer
local function normalize_pr_id(pr_id)
	if type(pr_id) == "table" then
		return pr_id[1]
	end
	return pr_id
end


---@param delta			integer
---@param files 		string[]
---@param pr			Pr
---@param diff_layout	DiffLayout
local function move(delta, files, pr, diff_layout)
	local idx = layout.qflist.move(delta)
	if not idx then
		return
	end

	local file = files[idx]
	if not file or file == "" then
		vim.notify(string.format("GhReview: missing file for quickfix entry %d", idx), vim.log.levels.WARN)
		return
	end

	M.diff(file, pr, diff_layout)
end

local function init_qf(files, pr, diff_layout)
	local qf_win = vim.api.nvim_get_current_win()
	local qf_buf = vim.api.nvim_win_get_buf(qf_win)

	layout.qflist.forward.func = function()
		move(1, files, pr, diff_layout)
	end
	layout.qflist.backward.func = function()
		move(-1, files, pr, diff_layout)
	end

	layout.qflist.map_iteration_keys(qf_buf, layout.qflist.forward, layout.qflist.backward)
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

	layout.qflist.set_files(files, "pr review")
	vim.cmd("copen")
	local diff_layout = layout.diff.new()
	init_qf(files, pr, diff_layout)
	vim.cmd("wincmd p")
	M.diff(files[1], pr, diff_layout)
end

return M
