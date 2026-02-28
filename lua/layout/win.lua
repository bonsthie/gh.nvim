local M = {}

function M.ok(winid)
	return winid and vim.api.nvim_win_is_valid(winid)
end

local function bufname(buf)
	local n = vim.api.nvim_buf_get_name(buf)
	if n == "" then return "[No Name]" end
	return n
end

function M.info(winid)
	if not M.ok(winid) then return "INVALID" end
	local buf = vim.api.nvim_win_get_buf(winid)
	local tab = vim.api.nvim_win_get_tabpage(winid)
	local cfg = vim.api.nvim_win_get_config(winid)
	return string.format(
		"win=%d tab=%d buf=%d (%s) floating=%s",
		winid, tab, buf, bufname(buf), tostring(cfg.relative ~= "")
	)
end

function M.binfo(buf)
  return string.format("buf=%d name=%s loaded=%s",
    buf,
    vim.api.nvim_buf_get_name(buf),
    tostring(vim.api.nvim_buf_is_loaded(buf))
  )
end

return M
