local cmd = require('cmd')

local ensure_message = "Git CLI 'git' not found in PATH. Install it: https://git-scm.com/downloads"

local git_cmd = cmd.new("git", { ensure_message = ensure_message })

local M = {}

M.cmd = git_cmd

---@param args string[]|nil
---@return CmdResponse
function M.run(args)
    return git_cmd(args)
end

return M
