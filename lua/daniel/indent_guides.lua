-- ~/.config/nvim/lua/daniel/indent_guides.lua
-- Native indent guides via 'listchars' (replaces indent-blankline.nvim).
-- 'leadmultispace' repeats its pattern over leading spaces, so a pattern one
-- indent wide draws "▏" at every indent level. 'leadtab' does the same for
-- leading tabs. Other whitespace is rendered exactly as without 'list'.

local CHAR = "▏"

-- Same exclusions as indent-blankline's defaults
local excluded_buftypes = { terminal = true, nofile = true, quickfix = true, prompt = true }
local excluded_filetypes = {
    [""] = true, lspinfo = true, checkhealth = true, help = true, man = true, gitcommit = true,
}

local function apply()
    local buf = vim.api.nvim_get_current_buf()
    if excluded_buftypes[vim.bo[buf].buftype] or excluded_filetypes[vim.bo[buf].filetype] then
        vim.opt_local.list = false
        return
    end
    -- shiftwidth() returns 'tabstop' when 'shiftwidth' is 0
    local sw = math.max(vim.fn.shiftwidth(), 1)
    vim.opt_local.listchars = {
        tab = "  ",
        leadtab = CHAR .. " ",
        leadmultispace = CHAR .. string.rep(" ", sw - 1),
        nbsp = " ",
    }
    vim.opt_local.list = true
end

local group = vim.api.nvim_create_augroup("daniel.indent_guides", { clear = true })
vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "TermOpen" }, { group = group, callback = apply })
vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = { "shiftwidth", "tabstop", "buftype" },
    callback = apply,
})
