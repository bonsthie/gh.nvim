local gh = require('cmd.gh').cmd

---@class Pr
---@field id string|number
---@field number integer|nil
---@field baseRefOid string
---@field headRefOid string
---@field baseRefName string
---@field headRefName string
---@field repoOwner string|nil
---@field repoName string|nil
---@field comments GhPrDiscussionComment[]
---@field reviews GhPrReviewSummary[]
---@field code_comments GhPrReviewCodeComment[]
---@field code_comments_err string|nil
---@field get_file_diff fun(self:Pr, file_name:string):PrDiffFile|nil, string|nil
---@field diff PrDiff
local Pr = {}
Pr.__index = Pr

---@class GhPrDiscussionComment
---@field id string|nil
---@field body string
---@field user string
---@field created_at string|nil
---@field url string|nil

---@class GhPrReviewSummary
---@field id string|nil
---@field body string
---@field user string
---@field state string|nil
---@field created_at string|nil
---@field url string|nil

---@class PrInfo
---@field baseRefOid string
---@field headRefOid string
---@field baseRefName string
---@field headRefName string
---@field number integer|nil
---@field repoOwner string|nil
---@field repoName string|nil
---@field comments GhPrDiscussionComment[]
---@field reviews GhPrReviewSummary[]

---@param url string|nil
---@return string|nil, string|nil, integer|nil
local function parse_repo_from_url(url)
	if type(url) ~= "string" then
		return nil, nil, nil
	end

	local owner, name, number = url:match('github%.com[:/]+([^/]+)/([^/]+)/pull/(%d+)')
	if not owner then
		owner, name, number = url:match('([^/]+)/([^/]+)/pull/(%d+)')
	end

	return owner, name, tonumber(number)
end

---@param raw_comments table|nil
---@return GhPrDiscussionComment[]
local function normalize_pr_comments(raw_comments)
	if type(raw_comments) ~= "table" then
		return {}
	end

	local nodes = raw_comments
	if type(raw_comments.nodes) == "table" then
		nodes = raw_comments.nodes
	end

	local comments = {}
	for _, node in ipairs(nodes) do
		if type(node) == "table" then
			local author = node.author and node.author.login or ""
			local created_at = node.createdAt
			if created_at == vim.NIL then
				created_at = nil
			end

			comments[#comments + 1] = {
				id = node.id,
				url = node.url,
				body = node.body or "",
				user = author,
				created_at = created_at,
			}
		end
	end

	return comments
end

---@param raw_reviews table|nil
---@return GhPrReviewSummary[]
local function normalize_pr_reviews(raw_reviews)
	if type(raw_reviews) ~= "table" then
		return {}
	end

	local nodes = raw_reviews
	if type(raw_reviews.nodes) == "table" then
		nodes = raw_reviews.nodes
	end

	local reviews = {}
	for _, node in ipairs(nodes) do
		if type(node) == "table" then
			local body = node.body or ""
			if body ~= "" then
				local author = node.author and node.author.login or ""
				local created_at = node.submittedAt or node.updatedAt or node.createdAt
				if created_at == vim.NIL then
					created_at = nil
				end
				local state = node.state
				if state == vim.NIL then
					state = nil
				end
				reviews[#reviews + 1] = {
					id = node.id,
					body = body,
					user = author,
					state = state,
					created_at = created_at,
					url = node.url,
				}
			end
		end
	end

	return reviews
end

local FIELDS = {
  "baseRefOid", "headRefOid", "baseRefName", "headRefName",
  "number", "headRepositoryOwner", "headRepository", "url",
  "comments", "reviews"
}

---@param pr_id string|number
---@return PrInfo|nil, string|nil
local function get_info(pr_id)
    local fields_arg = table.concat(FIELDS, ",")
    local ret = gh.pr.view({ pr_id, "--json", fields_arg })

    if not ret.ok then
        return nil, ret.stderr
    end

    local ok, raw_info = pcall(vim.json.decode, ret.stdout)
    if not ok then
        return nil, "Failed to decode JSON response"
    end

    local head_repo = raw_info.headRepository or {}
    local head_owner = raw_info.headRepositoryOwner or head_repo.owner or {}

    local repo_owner = head_owner.login or head_owner.name
    local repo_name = head_repo.name
    local pr_number = tonumber(raw_info.number) or tonumber(pr_id)

    if not (repo_owner and repo_name) then
        local url_owner, url_name, url_num = parse_repo_from_url(raw_info.url)
        repo_owner = repo_owner or url_owner
        repo_name = repo_name or url_name
        pr_number = pr_number or url_num
    end

    return {
        baseRefOid  = raw_info.baseRefOid,
        headRefOid  = raw_info.headRefOid,
        baseRefName = raw_info.baseRefName,
        headRefName = raw_info.headRefName,
        repoOwner   = repo_owner,
        repoName    = repo_name,
        number      = pr_number,
        comments    = normalize_pr_comments(raw_info.comments or {}),
        reviews     = normalize_pr_reviews(raw_info.reviews or {}),
    }, nil
end

---Create a PR wrapper hydrated with metadata fetched from `gh pr view`.
---Returns the populated object or an error string if the CLI call fails.
---@param pr_id string|number
---@return Pr|nil, string|nil
function Pr.new(pr_id)
	-- Look up ref/repo information before constructing the table so
	-- downstream helpers (diff, comments, etc.) have all required data.
	local info, err = get_info(pr_id)
	if not info then
		return nil, err
	end

	-- Attach the metadata and tag the table with the Pr metatable.
	local pr = setmetatable({
		id = pr_id,
		number = info.number,
		baseRefOid = info.baseRefOid,
		headRefOid = info.headRefOid,
		baseRefName = info.baseRefName,
		headRefName = info.headRefName,
		repoOwner = info.repoOwner,
		repoName = info.repoName,
		comments = info.comments or {},
		reviews = info.reviews or {},
		code_comments = {},
	}, Pr)

	if type(pr.get_code_comments) == "function" then
		local code_comments, comments_err = pr:get_code_comments()
		if type(code_comments) ~= "table" then
			code_comments = {}
		end
		pr.code_comments = code_comments
		pr.code_comments_err = comments_err
	else
		pr.code_comments = {}
		pr.code_comments_err = nil
	end

	return pr, nil
end

--- TODO use the get_info to get the file list insted
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

local CodeComments = require('pr.code_comments')
Pr.CodeComments = CodeComments
if type(CodeComments.extend) == 'function' then
	CodeComments.extend(Pr)
end

return Pr
