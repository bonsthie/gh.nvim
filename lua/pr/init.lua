local M = {}

local gh = require('cmd.gh').cmd

---@param pr_id string|number
---@return string[]
function M.get_files_list(pr_id)
	local ret = gh.pr.diff({ '--name-only', pr_id })
	if not ret.ok then
		return {}
	end

	return vim.split(ret.stdout, "\n", { plain = true })
end


---@class PrInfo
---@field baseRefOid string
---@field headRefOid string
---@field baseRefName string
---@field headRefName string

---@param pr_id string|number
---@return PrInfo|nil, string|nil
function M.get_info(pr_id)
	local ret = gh.pr.view({ "--json", "baseRefOid,headRefOid,baseRefName,headRefName", pr_id })

	if not ret.ok then
		return {}, ret.stderr
	end

	return vim.json.decode(ret.stdout), nil
end

return M
