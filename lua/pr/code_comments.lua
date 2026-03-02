local gh = require('cmd.gh').cmd
local PrComments = {}

---@class GhPrReviewCodeComment
---@field thread_id string
---@field id string
---@field url string
---@field body string
---@field user string
---@field parent_id string|nil
---@field parent_url string|nil
---@field created_at string|nil
---@field lsp lsp.Range
---@field path string
---@field line integer        -- 1-based line (same as GitHub "line")
---@field startLine integer   -- 1-based startLine (same as GitHub "startLine")

--- Turn GitHub reviewThreads GraphQL JSON into a flat list of comments with LSP range info.
---
--- Expects a decoded Lua table (vim.json.decode output) shaped like:
---   { data = { repository = { pullRequest = { reviewThreads = { nodes = {...} }}}}}
---
---@param resp table
---@return GhPrReviewCodeComment[]
local function gh_reviewthreads_to_comment_list(resp)
  local out = {}

  local threads =
    resp
    and resp.data
    and resp.data.repository
    and resp.data.repository.pullRequest
    and resp.data.repository.pullRequest.reviewThreads
    and resp.data.repository.pullRequest.reviewThreads.nodes

  if type(threads) ~= "table" then
    return out
  end

  for _, thread in ipairs(threads) do
    local path = thread.path
    local line = tonumber(thread.line) or 1
    local startLine = tonumber(thread.startLine) or line

    -- LSP: 0-based positions. We'll represent the whole line range [line-1, 0] -> [line-1, huge]
    -- so it highlights the line without needing column info.
    local lnum0 = math.max(line - 1, 0)
    local range = {
      start = { line = lnum0, character = 0 },
      ["end"] = { line = lnum0, character = 1000000 },
    }

    local comments = thread.comments and thread.comments.nodes
    if type(comments) == "table" then
      for _, c in ipairs(comments) do
        local author = c.author and c.author.login or ""
        local replyTo = c.replyTo
        if replyTo == vim.NIL then
          replyTo = nil
        end
        local createdAt = c.createdAt
        if createdAt == vim.NIL then
          createdAt = nil
        end

        out[#out + 1] = {
          thread_id = thread.id,
          id = c.id,
          url = c.url,
          body = c.body or "",
          user = author,
          parent_id = replyTo and replyTo.id or nil,
          parent_url = replyTo and replyTo.url or nil,
          created_at = createdAt,

          lsp = range,
          path = path,
          line = line,
          startLine = startLine,
        }
      end
    end
  end

  return out
end

local query = [[query PRReviewThreads(
  $owner: String!
  $name: String!
  $number: Int!
  $threadsFirst: Int = 100
  $commentsFirst: Int = 100
) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: $threadsFirst) {
        nodes {
          id
          path
          line
          startLine
          originalLine
          originalStartLine
          isResolved
          isOutdated

          comments(first: $commentsFirst) {
            nodes {
              id
              url
              body
              author { login }
              createdAt

              replyTo {
                id
                url
              }
            }
          }
        }
      }
    }
  }
}]]

---@param pr Pr
---@param file_name string|nil
---@return GhPrReviewCodeComment[], string|nil
function PrComments.get_code_comments(pr, file_name)
	if type(pr) ~= "table" then
		return {}, "Missing PR context"
	end

	local owner = pr.repoOwner
	local name = pr.repoName
	local number = pr.number or tonumber(pr.id)
	if owner == nil or name == nil or number == nil then
		return {}, "PR is missing repository metadata (owner/name/number)"
	end

	local args = {
		"-F",
		"owner=" .. owner,
		"-F",
		"name=" .. name,
		"-F",
		"number=" .. tostring(number),
		"-f",
		"query=" .. query,
	}

	local ret = gh.api.graphql(args)
	if not ret.ok then
		return {}, ret.stderr
	end

	local ok, decoded = pcall(vim.json.decode, ret.stdout)
	if not ok then
		return {}, string.format("Failed to parse review comments: %s", decoded)
	end

	local comments = gh_reviewthreads_to_comment_list(decoded)
	if type(file_name) == "string" and file_name ~= "" then
		local filtered = {}
		for _, comment in ipairs(comments) do
			if comment.path == file_name then
				filtered[#filtered + 1] = comment
			end
		end
		return filtered, nil
	end

	return comments, nil
end


---@param Pr Pr
function PrComments.extend(Pr)
	function Pr:get_code_comments(file_name)
		return PrComments.get_code_comments(self, file_name)
	end
end

return PrComments
