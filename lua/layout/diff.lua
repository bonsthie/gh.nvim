-- Keeps track of diff windows and recreates them when needed.
local DiffLayout = {}

DiffLayout.screen_one = nil
DiffLayout.screen_two = nil

local function create_layout()
    vim.cmd("silent only")
    DiffLayout.screen_one = vim.api.nvim_get_current_win()
    vim.cmd("rightbelow vsplit")
    DiffLayout.screen_two = vim.api.nvim_get_current_win()
end

local function ensure_layout()
    if not DiffLayout.screen_one or not vim.api.nvim_win_is_valid(DiffLayout.screen_one) then
        create_layout()
        return
    end

    if not DiffLayout.screen_two or not vim.api.nvim_win_is_valid(DiffLayout.screen_two) then
        vim.api.nvim_set_current_win(DiffLayout.screen_one)
        vim.cmd("rightbelow vsplit")
        DiffLayout.screen_two = vim.api.nvim_get_current_win()
    end
end

function DiffLayout.new()
    ensure_layout()

    return {
        screen_one = DiffLayout.screen_one,
        screen_two = DiffLayout.screen_two,
    }
end

return DiffLayout
