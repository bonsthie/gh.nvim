local M = {}

function M.save_tab_state()
	local dir = vim.fn.stdpath("state") .. "/myplugin"
	vim.fn.mkdir(dir, "p")
	local path = string.format("%s/session_%d.vim", dir, vim.loop.hrtime())

	vim.cmd("silent! mksession! " .. vim.fn.fnameescape(path))

	return { type = "session", path = path }
end

function M.restore_tab_state(handle)
	if not handle or handle.type ~= "session" then return end
	vim.cmd("silent! source " .. vim.fn.fnameescape(handle.path))
end

return M
