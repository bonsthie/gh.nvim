local Signs = {}

local SIGN_GROUP = "notif_group"
local SIGN_NAME = "NotifSign"
local SIGN_DEF = {
  text = "\226\151\143",
  texthl = "ErrorMsg",
}

local function ensure_sign_defined()
  vim.fn.sign_define(SIGN_NAME, SIGN_DEF)
end

---@param win integer
---@param comments GhPrReviewCodeComment[]|nil
function Signs.place_review_comments(win, comments)
  if not win or win == 0 then
    return
  end

  ensure_sign_defined()
  local bufnr = vim.api.nvim_win_get_buf(win)
  vim.fn.sign_unplace(SIGN_GROUP, { buffer = bufnr })

  if type(comments) ~= "table" then
    return
  end

  for _, comment in ipairs(comments) do
    local lnum = tonumber(comment.line)
    if lnum then
      vim.fn.sign_place(0, SIGN_GROUP, SIGN_NAME, bufnr, { lnum = lnum })
    end
  end
end

return Signs
