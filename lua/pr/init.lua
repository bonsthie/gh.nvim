local gh = require('cmd.gh').cmd

---@class Pr
---@field id string|number
---@field baseRefOid string
---@field headRefOid string
---@field baseRefName string
---@field headRefName string
---@field get_file_diff fun(self:Pr, file_name:string):PrDiffFile|nil, string|nil
---@field diff PrDiff
local Pr = {}
Pr.__index = Pr

---@class PrInfo
---@field baseRefOid string
---@field headRefOid string
---@field baseRefName string
---@field headRefName string

---@param pr_id string|number
---@return PrInfo|nil, string|nil
local function get_info(pr_id)
	local ret = gh.pr.view({ pr_id, "--json", "baseRefOid,headRefOid,baseRefName,headRefName"})

	if not ret.ok then
		return nil, ret.stderr
	end

	return vim.json.decode(ret.stdout), nil
end

---@param pr_id string|number
---@return Pr|nil, string|nil
function Pr.new(pr_id)
	local info, err = get_info(pr_id)
	if not info then
		return nil, err
	end

	return setmetatable({
		id = pr_id,
		baseRefOid = info.baseRefOid,
		headRefOid = info.headRefOid,
		baseRefName = info.baseRefName,
		headRefName = info.headRefName,
	}, Pr), nil
end

---@return string[], string|nil
function Pr:get_files_list()
	local ret = gh.pr.diff({ '--name-only', self.id })
	if not ret.ok then
		local msg = ret.stderr
		if msg == '' then
			msg = string.format('Failed to list files for PR %s', tostring(self.id))
		end
		return {}, msg
	end

	local files = vim.split(ret.stdout, '\n', { trimempty = true })
	return files, nil
end

local Diff = require('pr.diff')
Pr.diff = Diff
if type(Diff.extend) == 'function' then
	Diff.extend(Pr)
end

return Pr
