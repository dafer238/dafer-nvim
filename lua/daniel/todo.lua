-- ~/.config/nvim/lua/daniel/todo.lua
-- Native TODO/FIXME highlighting (replaces todo-comments.nvim + plenary).
-- Same keywords, colours and look as todo-comments' defaults: the keyword
-- (with its colon) gets a coloured background, the rest of the line after it
-- is coloured with the same foreground. Uses window-local matchadd(), so the
-- core regex engine does the work at redraw time; no buffer scanning.

local kinds = {
    -- name      keywords                                             colour source
    { "Fix",  { "FIX", "FIXME", "BUG", "FIXIT", "ISSUE" },               "DiagnosticError" },
    { "Todo", { "TODO" },                                                "DiagnosticInfo" },
    { "Hack", { "HACK" },                                                "DiagnosticWarn" },
    { "Warn", { "WARN", "WARNING", "XXX" },                              "DiagnosticWarn" },
    { "Perf", { "PERF", "OPTIM", "PERFORMANCE", "OPTIMIZE" },            "Identifier" },
    { "Note", { "NOTE", "INFO" },                                        "DiagnosticHint" },
    { "Test", { "TEST", "TESTING", "PASSED", "FAILED" },                 "Identifier" },
}

local function fg_of(name)
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    return hl.fg
end

local function define_highlights()
    local bg = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg
    for _, k in ipairs(kinds) do
        local color = fg_of(k[3])
        vim.api.nvim_set_hl(0, "TodoBg" .. k[1], { fg = bg, bg = color, bold = true })
        vim.api.nvim_set_hl(0, "TodoFg" .. k[1], { fg = color })
    end
end

local function add_matches()
    if vim.w.todo_matches then return end
    local ids = {}
    for _, k in ipairs(kinds) do
        local words = table.concat(k[2], "|")
        -- keyword followed by optional spaces and a colon, like todo-comments' default pattern
        ids[#ids + 1] = vim.fn.matchadd("TodoBg" .. k[1], [[\v<(]] .. words .. [[)\s*:]], 11)
        ids[#ids + 1] = vim.fn.matchadd("TodoFg" .. k[1], [[\v<(]] .. words .. [[)\s*:\zs.*]], 10)
    end
    vim.w.todo_matches = ids
end

local group = vim.api.nvim_create_augroup("daniel.todo", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = define_highlights })
vim.api.nvim_create_autocmd({ "VimEnter", "WinNew", "WinEnter", "BufWinEnter" }, {
    group = group,
    callback = add_matches,
})

define_highlights()
