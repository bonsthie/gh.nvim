---@class QfMap
---@field keymap string
---@field func fun()

---@class QfList
---@field forward QfMap
---@field backward QfMap
local QfList = {}
QfList.__index = QfList


function QfList.move(delta)
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



QfList.forward = {
	keymap = "]q",
	func = function()
		QfList.move(1)
	end,
}

QfList.backward = {
	keymap = "[q",
	func = function()
		QfList.move(-1)
	end,
}


---@param map_forward QfMap|nil
---@param map_backward QfMap|nil
function QfList.map_iteration_keys(bufnr, map_forward, map_backward)
	if not bufnr or bufnr == 0 then
		return
	end

	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local opts = { buffer = bufnr, silent = true }

	local mappings = {
		map_forward or QfList.forward,
		map_backward or QfList.backward,
	}

	for _, map in ipairs(mappings) do
		if map and map.keymap and map.func then
			vim.keymap.set("n", map.keymap, map.func, opts)
		end
	end
end

--- to change place
---@param diff_layout DiffLayout|nil
---@param map_forward QfMap|nil
---@param map_backward QfMap|nil
function QfList.map_diff_layout_buffers(diff_layout, map_forward, map_backward)
	if not diff_layout then
		return
	end

	local wins = { diff_layout.screen_one, diff_layout.screen_two }
	for _, win in ipairs(wins) do
		if win and vim.api.nvim_win_is_valid(win) then
			local buf = vim.api.nvim_win_get_buf(win)
			QfList.map_iteration_keys(buf, map_forward, map_backward)
		end
	end
end


function QfList.set_files(files, title)
	local items = {}
	for _, f in ipairs(files) do
		if f ~= "" then
			table.insert(items, { filename = f, lnum = 1, col = 1, text = "file" })
		end
	end
	vim.fn.setqflist({}, "r", { title = title or "files", items = items })
	vim.cmd("copen")
end

return QfList
