local M = {}

local pr = require('pr')
local diff_layout = require('diff.layout')
local win = require('diff.win')

M.current_diff_layout = nil

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



local function move_in_quickfix(delta)
	local qf = vim.fn.getqflist({ idx = 0, size = 0 })
	local size = qf.size or 0
	if size == 0 then
		vim.notify("GhReview: quickfix is empty.", vim.log.levels.WARN)
		return nil
	end

	local new_idx = (qf.idx or 1) + delta
	if new_idx < 1 or new_idx > size then
		vim.notify("GhReview: no more entries.", vim.log.levels.INFO)
		return nil
	end


	vim.fn.setqflist({}, 'r', { idx = new_idx })
	return new_idx
end


function M.update_diff(file_left, file_right)
	-- Load the files into buffers (without jumping focus)
	local buf_left = vim.fn.bufadd(file_left)
	local buf_right = vim.fn.bufadd(file_right)
	vim.fn.bufload(buf_left)
	vim.fn.bufload(buf_right)

	print(win.info(M.current_diff_layout.screen_one))
	print(win.info(M.current_diff_layout.screen_two))
	print("file_left:", file_left)
	print("file_right:", file_right)
	print("left:", win.binfo(buf_left))
	print("right:", win.binfo(buf_right))

	assert(win.ok(M.current_diff_layout.screen_one),
		"screen_one window invalid: " .. win.info(M.current_diff_layout.screen_one))
	assert(win.ok(M.current_diff_layout.screen_two),
		"screen_two window invalid: " .. win.info(M.current_diff_layout.screen_two))


	-- Assign buffers to windows
	vim.api.nvim_win_set_buf(M.current_diff_layout.screen_one, buf_left)
	vim.api.nvim_win_set_buf(M.current_diff_layout.screen_two, buf_right)

	-- Refresh Diff Mode
	vim.api.nvim_win_call(M.current_diff_layout.screen_one, function() vim.cmd("diffthis") end)
	vim.api.nvim_win_call(M.current_diff_layout.screen_two, function() vim.cmd("diffthis") end)
end

function M.diff(file)
	print(file)
	M.update_diff()
end

local function map_iteration_keys(files, bufnr)
	local opts = { buffer = bufnr, silent = true }

	vim.keymap.set("n", "]q", function()
		local idx = move_in_quickfix(1)
		if idx then
			M.diff(files[idx])
		end
	end, opts)

	vim.keymap.set("n", "[q", function()
		local idx = move_in_quickfix(-1)
		if idx then
			M.diff(files[idx])
		end
	end, opts)
end


function M.review(pr_id)
	local files = pr.get_files_list(pr_id)

	local pr_info, err = pr.get_info(pr_id)
	if pr_info == nil then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	map_iteration_keys(files, vim.api.nvim_get_current_buf())

	set_qf_files(files, "pr review")

	vim.cmd("copen")
	vim.cmd("wincmd p")
	M.current_diff_layout = diff_layout.new()
	M.diff(files[1])
end

return M
