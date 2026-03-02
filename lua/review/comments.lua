local M = {}

local function deepcopy_comments(list)
  if type(list) ~= "table" then
    return {}
  end
  return vim.deepcopy(list)
end

local function compare_created(a, b)
  local at = type(a) == "table" and a.created_at or nil
  local bt = type(b) == "table" and b.created_at or nil
  if at == bt then
    local aid = type(a) == "table" and a.id or ""
    local bid = type(b) == "table" and b.id or ""
    return tostring(aid) < tostring(bid)
  end
  if at == nil or at == "" then
    return false
  end
  if bt == nil or bt == "" then
    return true
  end
  return at < bt
end

local function format_location(comment)
  if comment.path and comment.line then
    return string.format("%s:%s", comment.path, tostring(comment.line))
  elseif comment.path then
    return comment.path
  elseif comment.line then
    return string.format("line %s", tostring(comment.line))
  end
  return "unknown location"
end

local function get_thread_key(comment)
  if comment.thread_id then
    return comment.thread_id
  end
  local parts = {
    comment.path or "unknown",
    tostring(comment.startLine or comment.line or "?"),
    tostring(comment.line or "?"),
  }
  return table.concat(parts, ":")
end

local function sort_comment_list(list)
  table.sort(list, compare_created)
end

local function emit_comment(comment_by_id, bucket, comment, depth, output)
  local prefix = string.rep("  ", depth)
  local indicator = depth > 0 and "↳ " or ""
  local author = comment.user and comment.user ~= "" and comment.user or "unknown"
  local timestamp = comment.created_at and (" @ " .. comment.created_at) or ""
  local relation = ""
  if comment.parent_id then
    local parent = comment_by_id[comment.parent_id]
    local parent_author = parent and parent.user and parent.user ~= "" and parent.user or "unknown"
    relation = string.format(" (reply to %s)", parent_author)
  end
  output[#output + 1] = string.format("%s%s[%s%s]%s", prefix, indicator, author, timestamp, relation)

  local body = (comment.body or ""):gsub("\r", "")
  local body_lines = vim.split(body, "\n", { plain = true })
  if #body_lines == 0 then
    body_lines = { "" }
  end
  for _, line in ipairs(body_lines) do
    output[#output + 1] = string.format("%s  %s", prefix, line)
  end

  if comment.url and comment.url ~= "" then
    output[#output + 1] = string.format("%s  %s", prefix, comment.url)
  end

  output[#output + 1] = ""

  local children = bucket.children[comment.id]
  if children then
    for _, child in ipairs(children) do
      emit_comment(comment_by_id, bucket, child, depth + 1, output)
    end
  end
end

local function build_threads(review_comments)
  local ordered_threads = {}
  local threads = {}
  local comment_by_id = {}

  for _, comment in ipairs(review_comments) do
    local key = get_thread_key(comment)
    local bucket = threads[key]
    if not bucket then
      bucket = {
        thread_id = comment.thread_id,
        comments = {},
        children = {},
        roots = {},
        first_created_at = nil,
      }
      threads[key] = bucket
      ordered_threads[#ordered_threads + 1] = bucket
    end
    bucket.comments[#bucket.comments + 1] = comment
    comment_by_id[comment.id] = comment

    local created = comment.created_at
    if created and created ~= "" then
      if bucket.first_created_at == nil or created < bucket.first_created_at then
        bucket.first_created_at = created
      end
    end
  end

  for _, bucket in ipairs(ordered_threads) do
    for _, comment in ipairs(bucket.comments) do
      if comment.parent_id and comment_by_id[comment.parent_id] then
        local children = bucket.children[comment.parent_id]
        if not children then
          children = {}
          bucket.children[comment.parent_id] = children
        end
        children[#children + 1] = comment
      else
        bucket.roots[#bucket.roots + 1] = comment
      end
    end
  end

  for _, bucket in ipairs(ordered_threads) do
    sort_comment_list(bucket.roots)
    for _, children in pairs(bucket.children) do
      sort_comment_list(children)
    end
  end

  return ordered_threads, comment_by_id
end

local function enqueue_events(general_comments, ordered_threads, review_summaries)
  local events = {}
  local event_seq = 0

  for _, comment in ipairs(general_comments) do
    event_seq = event_seq + 1
    events[#events + 1] = {
      type = "conversation",
      created_at = comment.created_at or "",
      index = event_seq,
      comment = comment,
    }
  end

  for _, review in ipairs(review_summaries) do
    event_seq = event_seq + 1
    events[#events + 1] = {
      type = "review",
      created_at = review.created_at or "",
      index = event_seq,
      review = review,
    }
  end

  for _, bucket in ipairs(ordered_threads) do
    event_seq = event_seq + 1
    events[#events + 1] = {
      type = "thread",
      created_at = bucket.first_created_at or "",
      index = event_seq,
      bucket = bucket,
    }
  end

  table.sort(events, function(a, b)
    local at = a.created_at or ""
    local bt = b.created_at or ""
    if at == bt then
      return a.index < b.index
    end
    if at == "" then
      return false
    end
    if bt == "" then
      return true
    end
    return at < bt
  end)

  return events
end

local function render_conversation_comment(comment, output)
  local author = comment.user and comment.user ~= "" and comment.user or "unknown"
  local timestamp = comment.created_at and (" @ " .. comment.created_at) or ""
  output[#output + 1] = string.format("Conversation [%s%s]", author, timestamp)

  local body = (comment.body or ""):gsub("\r", "")
  local body_lines = vim.split(body, "\n", { plain = true })
  if #body_lines == 0 then
    body_lines = { "" }
  end
  for _, line in ipairs(body_lines) do
    output[#output + 1] = "  " .. line
  end

  if comment.url and comment.url ~= "" then
    output[#output + 1] = "  " .. comment.url
  end

  output[#output + 1] = ""
end

local function render_thread(thread_idx, bucket, comment_by_id, output)
  local first_comment = bucket.comments[1]
  local location = first_comment and format_location(first_comment) or "unknown location"
  output[#output + 1] = string.format("Thread %d: %s", thread_idx, location)
  output[#output + 1] = string.rep("-", 12)

  local roots = bucket.roots
  if #roots == 0 then
    roots = bucket.comments
  end
  for _, comment in ipairs(roots) do
    emit_comment(comment_by_id, bucket, comment, 0, output)
  end
end

local function render_review_summary(review, output)
  local author = review.user and review.user ~= "" and review.user or "unknown"
  local timestamp = review.created_at and (" @ " .. review.created_at) or ""
  local state = review.state and string.format(" (%s)", review.state) or ""
  output[#output + 1] = string.format("Review [%s%s]%s", author, timestamp, state)

  local body = (review.body or ""):gsub("\r", "")
  local body_lines = vim.split(body, "\n", { plain = true })
  if #body_lines == 0 then
    body_lines = { "" }
  end
  for _, line in ipairs(body_lines) do
    output[#output + 1] = "  " .. line
  end

  if review.url and review.url ~= "" then
    output[#output + 1] = "  " .. review.url
  end

  output[#output + 1] = ""
end

---@param code_comments GhPrReviewCodeComment[]|nil
---@param discussion_comments GhPrDiscussionComment[]|nil
---@param review_summaries GhPrReviewSummary[]|nil
function M.print_combined(code_comments, discussion_comments, review_summaries)
  local review_comments = deepcopy_comments(code_comments)
  local general_comments = deepcopy_comments(discussion_comments)
  local pr_reviews = deepcopy_comments(review_summaries)

  if vim.tbl_isempty(review_comments) and vim.tbl_isempty(general_comments) and vim.tbl_isempty(pr_reviews) then
    vim.api.nvim_out_write("GhReview: no review comments found\n")
    return
  end

  table.sort(review_comments, compare_created)
  table.sort(general_comments, compare_created)
  table.sort(pr_reviews, compare_created)

  local ordered_threads, comment_by_id = build_threads(review_comments)
  local events = enqueue_events(general_comments, ordered_threads, pr_reviews)

  local output = {}
  local thread_count = 0
  for _, event in ipairs(events) do
    if event.type == "conversation" then
      render_conversation_comment(event.comment, output)
    elseif event.type == "review" then
      render_review_summary(event.review, output)
    else
      thread_count = thread_count + 1
      render_thread(thread_count, event.bucket, comment_by_id, output)
    end
  end

  vim.api.nvim_out_write(table.concat(output, "\n"))
end

return M
