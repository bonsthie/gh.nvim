---@class DiffLayout
---@field screen_one integer # |window-ID|
---@field screen_two integer # |window-ID|
local DiffLayout = {}
DiffLayout.__index = DiffLayout

---@return DiffLayout
function DiffLayout.new()
	vim.cmd("silent only")
	local screen_one = vim.api.nvim_get_current_win()
	vim.cmd("rightbelow vsplit")
	local screen_two = vim.api.nvim_get_current_win()

	return setmetatable({
		screen_one = screen_one,
		screen_two = screen_two,
	}, DiffLayout)
end

function DiffLayout:update(file_left, file_right, type)
	if not file_left or not file_right then
		return
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
	vim.api.nvim_win_set_buf(self.screen_one, buf_left)
	vim.api.nvim_win_set_buf(self.screen_two, buf_right)

	-- Refresh Diff Mode
	vim.api.nvim_win_call(self.screen_one, function()
		vim.cmd("diffoff!")
		vim.cmd("diffthis")
	end)
	vim.api.nvim_win_call(self.screen_two, function()
		vim.cmd("diffthis")
	end)
end

return DiffLayout
