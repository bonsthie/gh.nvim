local M = {}

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


local function map_iteration_keys(bufnr)
	if not bufnr or bufnr == 0 then
		return
	end

	if not (M.review_files and M.review_pr) then
		return
	end

	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local opts = { buffer = bufnr, silent = true }

	local function move(delta)
		local idx = move_in_quickfix(delta)
		if not idx then
			return
		end

		local file = M.review_files[idx]
		if not file or file == "" then
			vim.notify(string.format("GhReview: missing file for quickfix entry %d", idx), vim.log.levels.WARN)
			return
		end

		M.diff(file, M.review_pr)
	end

	vim.keymap.set("n", "]q", function()
		move(1)
	end, opts)

	vim.keymap.set("n", "[q", function()
		move(-1)
	end, opts)
end

function M.update_diff(file_left, file_right, type)
	if not file_left or not file_right then
		return
	end

	if not M.current_diff_layout then
		M.current_diff_layout = diff_layout.new()
	end

	if not (win.ok(M.current_diff_layout.screen_one) and win.ok(M.current_diff_layout.screen_two)) then
		M.current_diff_layout = diff_layout.new()
	end

	-- Load the files into buffers (without jumping focus)
	local buf_left = vim.fn.bufadd(file_left)
	local buf_right = vim.fn.bufadd(file_right)
	vim.fn.bufload(buf_left)
	vim.fn.bufload(buf_right)

	if type and type ~= "" then
		vim.bo[buf_left].filetype = type
		vim.bo[buf_right].filetype = type
	end

	-- Assign buffers to windows
	vim.api.nvim_win_set_buf(M.current_diff_layout.screen_one, buf_left)
	vim.api.nvim_win_set_buf(M.current_diff_layout.screen_two, buf_right)

	map_iteration_keys(buf_left)
	map_iteration_keys(buf_right)

	-- Refresh Diff Mode
	vim.api.nvim_win_call(M.current_diff_layout.screen_one, function()
		vim.cmd("diffoff!")
		vim.cmd("diffthis")
	end)
	vim.api.nvim_win_call(M.current_diff_layout.screen_two, function()
		vim.cmd("diffthis")
	end)
end


return M
