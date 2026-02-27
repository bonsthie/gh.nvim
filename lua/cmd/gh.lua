local cmd = require('cmd')

local ensure_message = "GitHub CLI 'gh' not found in PATH. Install it: https://cli.github.com/"

local gh_cmd = cmd.new("gh", { ensure_message = ensure_message })

local GhModule = {}

GhModule.cmd = gh_cmd

---@param args string[]|nil
---@return CmdResponse
function GhModule.run(args)
	return gh_cmd(args)
end

return GhModule
