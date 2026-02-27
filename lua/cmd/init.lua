---@class CmdResponse
---@field ok boolean
---@field code integer
---@field stdout string
---@field stderr string

---@class CmdProxy: fun(...: any): CmdResponse
---@field _prefix? string[]
---@field _opts? table
---@field _exec? fun(args: string[], opts: table): CmdResponse
---@field [string] CmdProxy
---@overload fun(self: CmdProxy, ...: any): CmdResponse
local CmdProxy = {}

---@class Cmd : CmdProxy
local Cmd = {}

local function make_executor(bin, opts)
	opts = opts or {}

	local function has_bin()
		return vim.fn.executable(bin) == 1
	end

	local function ensure_bin()
		if not has_bin() then
			local message = opts.ensure_message
				or string.format("Command '%s' not found in PATH.", bin)
			return false, message
		end
		return true
	end

	return function(args)
		args = args or {}

		local ok, err = ensure_bin()
		if not ok then
			return { ok = false, code = -1, stdout = "", stderr = err }
		end

		local cmd = vim.list_extend({ bin }, args)
		local obj = vim.system(cmd, { text = true }):wait()

		return {
			ok = obj.code == 0,
			code = obj.code,
			stdout = obj.stdout or "",
			stderr = obj.stderr or "",
		}
	end
end

Cmd.__index = function(self, key)
	local v = rawget(self, key)
	if v ~= nil then return v end

	local next_prefix = vim.list_extend(vim.deepcopy(self._prefix), { key })
	return setmetatable({
		_bin = self._bin,
		_prefix = next_prefix,
		_opts = self._opts,
		_exec = self._exec,
	}, Cmd)
end

---@return CmdResponse
Cmd.__call = function(self, ...)
	local args = vim.list_extend(vim.deepcopy(self._prefix), ...)
	return self._exec(args, self._opts)
end

---@return CmdProxy
function CmdProxy.new(bin, opts)
	assert(type(bin) == "string" and bin ~= "", "cmd.new requires the command name")

	local parsed_opts = opts or {}
	local executor = make_executor(bin, parsed_opts)

	return setmetatable({
		_bin = bin,
		_prefix = {},
		_opts = parsed_opts,
		_exec = executor,
	}, Cmd)
end

---@return CmdResponse
function CmdProxy.run(bin, args, opts)
	local executor = make_executor(bin, opts)
	return executor(args)
end

return CmdProxy
