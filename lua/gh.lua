local M = {}

local function has_gh()
	return vim.fn.executable("gh") == 1
end

local function ensure_gh()
	if not has_gh() then
		return false, "GitHub CLI 'gh' not found in PATH. Install it: https://cli.github.com/"
	end
	return true
end

local function exec_gh(args)
	args = args or {}

	local ok, err = ensure_gh()
	if not ok then
		local res = { ok = false, code = -1, stdout = "", stderr = err }
		return res
	end

	local cmd = vim.list_extend({ "gh" }, args)
	print(vim.inspect(cmd))
	local obj = vim.system(cmd, { text = true }):wait()

	return {
		ok = obj.code == 0,
		code = obj.code,
		stdout = obj.stdout or "",
		stderr = obj.stderr or "",
	}
end

local Gh = {}

Gh.__index = function(self, key)
	-- get fields
	local v = rawget(self, key)
	if v ~= nil then return v end


	local next_prefix = vim.list_extend(vim.deepcopy(self._prefix), { key })
	print(vim.inspect(next_prefix))
	return setmetatable({
		_prefix = next_prefix,
		_opts = self._opts,
		_exec = self._exec,
	}, Gh)
end

Gh.__call = function(self, ...)
	local args = vim.list_extend(vim.deepcopy(self._prefix), ...)
	return self._exec(args, self._opts)
end

local function new(opts)
	return setmetatable({
		_prefix = {},
		_opts = opts or {},
		_exec = exec_gh,
	}, Gh)
end

M.gh = new()
M.run = exec_gh

return M
