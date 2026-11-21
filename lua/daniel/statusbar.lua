-- ~/.config/nvim/lua/daniel/statusbar.lua
-- Native 'statusline', flat blocks (same sections as the old lualine layout):
--   [mode] [branch diff lsp-progress] [diagnostics filename] ... [encoding filetype] [progress] [location]

local M = {}

-- Flat blocks: each section is ' text ' on its own background, sections sit
-- flush against each other, and components inside a section are split by '│'.
local CSEP = '│'

local mode_names = {
    n = 'NORMAL', no = 'O-PENDING', nov = 'O-PENDING', noV = 'O-PENDING', ['no\22'] = 'O-PENDING',
    niI = 'NORMAL', niR = 'NORMAL', niV = 'NORMAL', nt = 'NORMAL', ntT = 'NORMAL',
    v = 'VISUAL', vs = 'VISUAL', V = 'V-LINE', Vs = 'V-LINE', ['\22'] = 'V-BLOCK', ['\22s'] = 'V-BLOCK',
    s = 'SELECT', S = 'S-LINE', ['\19'] = 'S-BLOCK',
    i = 'INSERT', ic = 'INSERT', ix = 'INSERT',
    R = 'REPLACE', Rc = 'REPLACE', Rx = 'REPLACE', Rv = 'V-REPLACE', Rvc = 'V-REPLACE', Rvx = 'V-REPLACE',
    c = 'COMMAND', cv = 'EX', ce = 'EX', cr = 'COMMAND',
    r = 'REPLACE', rm = 'MORE', ['r?'] = 'CONFIRM', ['!'] = 'SHELL', t = 'TERMINAL',
}

-- Mode -> colour family (same grouping as lualine themes)
local function mode_family(m)
    local c = m:sub(1, 1)
    if c == 'i' then return 'insert' end
    if c == 'v' or c == 'V' or c == '\22' or c == 's' or c == 'S' or c == '\19' then return 'visual' end
    if c == 'R' or c == 'r' then return 'replace' end
    if c == 'c' or c == '!' then return 'command' end
    if c == 't' then return 'terminal' end
    return 'normal'
end

local function hl_attr(name, attr)
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if ok and hl[attr] then return string.format('#%06x', hl[attr]) end
end

-- Colours: gruvbox-material palette (as its lualine theme does), with a fallback
-- to existing highlight groups for other colourschemes.
local function palette()
    local ok, conf = pcall(vim.fn['gruvbox_material#get_configuration'])
    if ok and type(conf) == 'table' then
        local okp, p = pcall(vim.fn['gruvbox_material#get_palette'], conf.background, conf.foreground,
            conf.colors_override)
        if okp and type(p) == 'table' then
            local function c(k) return p[k] and p[k][1] end
            return {
                normal = c('grey2'), insert = c('bg_green'), visual = c('bg_red'),
                replace = c('bg_yellow'), command = c('blue'), terminal = c('purple'),
                a_fg = c('bg0'), b_bg = c('bg_statusline3'), b_fg = c('fg1'),
                c_bg = c('bg_statusline1'), c_fg = c('fg1'), inactive_fg = c('grey1'),
            }
        end
    end
    return {
        normal = hl_attr('Comment', 'fg'), insert = hl_attr('String', 'fg'), visual = hl_attr('Error', 'fg'),
        replace = hl_attr('WarningMsg', 'fg'), command = hl_attr('Function', 'fg'),
        terminal = hl_attr('Constant', 'fg'),
        a_fg = hl_attr('Normal', 'bg'), b_bg = hl_attr('CursorLine', 'bg'), b_fg = hl_attr('Normal', 'fg'),
        c_bg = hl_attr('StatusLine', 'bg'), c_fg = hl_attr('StatusLine', 'fg'), inactive_fg = hl_attr('Comment', 'fg'),
    }
end

local colors = {}

local function define_highlights()
    colors = palette()
    local set = vim.api.nvim_set_hl
    for _, fam in ipairs({ 'normal', 'insert', 'visual', 'replace', 'command', 'terminal' }) do
        local bg = colors[fam]
        set(0, 'StlA_' .. fam, { fg = colors.a_fg, bg = bg, bold = true })
    end
    set(0, 'StlB', { fg = colors.b_fg, bg = colors.b_bg })
    set(0, 'StlC', { fg = colors.c_fg, bg = colors.c_bg })
    set(0, 'StlInactive', { fg = colors.inactive_fg, bg = colors.c_bg })
    -- Coloured items inside sections (diff in b, diagnostics in c)
    local items = {
        StlDiffAdd = { 'GitSignsAdd', colors.b_bg }, StlDiffChange = { 'GitSignsChange', colors.b_bg },
        StlDiffDelete = { 'GitSignsDelete', colors.b_bg },
        StlDiagError = { 'DiagnosticError', colors.c_bg }, StlDiagWarn = { 'DiagnosticWarn', colors.c_bg },
        StlDiagInfo = { 'DiagnosticInfo', colors.c_bg }, StlDiagHint = { 'DiagnosticHint', colors.c_bg },
    }
    for name, spec in pairs(items) do
        set(0, name, { fg = hl_attr(spec[1], 'fg'), bg = spec[2] })
    end
    M._icon_hls = {}
end

-- Filetype icon highlight: icon fg on section-c background
local function icon_hl(group)
    if not group then return 'StlC' end
    local name = 'StlIcon_' .. group
    if not M._icon_hls[name] then
        vim.api.nvim_set_hl(0, name, { fg = hl_attr(group, 'fg'), bg = colors.c_bg })
        M._icon_hls[name] = true
    end
    return name
end

-- Escape '%' so text is shown literally in the statusline
local function esc(s) return (s:gsub('%%', '%%%%')) end

local function join(parts, sep)
    local out = {}
    for _, p in ipairs(parts) do
        if p and p ~= '' then out[#out + 1] = p end
    end
    return table.concat(out, ' ' .. sep .. ' ')
end

-- LSP work-done progress, one entry per (client, token) while it is running.
-- Tracked from the events themselves rather than vim.lsp.status(), which
-- drains a shared ring buffer and only reports what arrived since last call.
local lsp_tasks = {} ---@type table<string, {title:string?, message:string?, percentage:integer?, time:integer, done:boolean}>
local STALE_MS = 30000 -- drop a task that sends nothing for this long (server never sent 'end')

local function progress_text()
    local now = vim.uv.now()
    local parts = {}
    for key, p in pairs(lsp_tasks) do
        if now - p.time > STALE_MS then
            lsp_tasks[key] = nil
        else
            local text = p.title or ''
            if p.message and p.message ~= '' then
                text = text ~= '' and (text .. ': ' .. p.message) or p.message
            end
            if p.percentage and not p.done then
                text = string.format('%d%% ', p.percentage) .. text
            end
            parts[#parts + 1] = text
        end
    end
    table.sort(parts)
    return table.concat(parts, ', ')
end

local function branch(buf)
    local head = vim.b[buf].gitsigns_head
    if not head or head == '' then return '' end
    return ' ' .. esc(head)
end

local function diff(buf)
    local d = vim.b[buf].gitsigns_status_dict
    if not d then return '' end
    local out = {}
    if (d.added or 0) > 0 then out[#out + 1] = '%#StlDiffAdd#+' .. d.added end
    if (d.changed or 0) > 0 then out[#out + 1] = '%#StlDiffChange#~' .. d.changed end
    if (d.removed or 0) > 0 then out[#out + 1] = '%#StlDiffDelete#-' .. d.removed end
    if #out == 0 then return '' end
    return table.concat(out, ' ') .. '%#StlB#'
end

local diag_symbols = {
    { vim.diagnostic.severity.ERROR, 'StlDiagError', '󰅚 ' },
    { vim.diagnostic.severity.WARN, 'StlDiagWarn', '󰀪 ' },
    { vim.diagnostic.severity.INFO, 'StlDiagInfo', '󰋽 ' },
    { vim.diagnostic.severity.HINT, 'StlDiagHint', '󰌶 ' },
}

local function diagnostics(buf)
    local counts = vim.diagnostic.count(buf)
    local out = {}
    for _, s in ipairs(diag_symbols) do
        local n = counts[s[1]]
        if n and n > 0 then out[#out + 1] = '%#' .. s[2] .. '#' .. s[3] .. n end
    end
    if #out == 0 then return '' end
    return table.concat(out, ' ') .. '%#StlC#'
end

local function filename(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    local out = name == '' and '[No Name]' or esc(vim.fn.fnamemodify(name, ':t'))
    if vim.bo[buf].modified then out = out .. ' [+]' end
    if not vim.bo[buf].modifiable or vim.bo[buf].readonly then out = out .. ' [-]' end
    return out
end

local function filetype(buf)
    local ft = vim.bo[buf].filetype
    if ft == '' then return '' end
    local ok, devicons = pcall(require, 'nvim-web-devicons')
    if ok then
        local name = vim.api.nvim_buf_get_name(buf)
        local icon, group = devicons.get_icon(vim.fn.fnamemodify(name, ':t'), vim.fn.fnamemodify(name, ':e'))
        if not icon then icon, group = devicons.get_icon_by_filetype(ft) end
        if icon then return '%#' .. icon_hl(group) .. '#' .. icon .. '%#StlC# ' .. ft end
    end
    return ft
end

local function encoding(buf)
    local enc = vim.bo[buf].fileencoding
    return enc ~= '' and enc or vim.o.encoding
end

local function progress(win, buf)
    local line = vim.api.nvim_win_get_cursor(win)[1]
    local total = vim.api.nvim_buf_line_count(buf)
    if line == 1 then return 'Top' end
    if line == total then return 'Bot' end
    return string.format('%2d%%%%', math.floor(line / total * 100))
end

function M.render()
    local win = vim.g.statusline_winid
    local buf = vim.api.nvim_win_get_buf(win)

    if win ~= vim.api.nvim_get_current_win() then
        -- Inactive window: filename ... location
        return '%#StlInactive# ' .. filename(buf) .. '%=%3l:%-2v '
    end

    local m = vim.api.nvim_get_mode().mode
    local fam = mode_family(m)
    local a = '%#StlA_' .. fam .. '# ' .. (mode_names[m] or m:upper()) .. ' '
    local b = join({ branch(buf), diff(buf), esc(progress_text()) }, CSEP)
    local c = join({ diagnostics(buf), filename(buf) }, CSEP)
    local x = join({ encoding(buf), filetype(buf) }, CSEP)
    local y = progress(win, buf)
    local z = '%3l:%-2v'

    local left = a .. (b ~= '' and ('%#StlB# ' .. b .. ' ') or '')
    local right = '%#StlB# ' .. y .. ' %#StlA_' .. fam .. '# ' .. z .. ' '
    return left .. '%#StlC# ' .. c .. '%=' .. x .. ' ' .. right
end

function M.setup()
    define_highlights()

    vim.o.statusline = "%!v:lua.require'daniel.statusbar'.render()"

    local group = vim.api.nvim_create_augroup('daniel.statusbar', { clear = true })
    vim.api.nvim_create_autocmd('ColorScheme', {
        group = group,
        callback = define_highlights,
    })
    -- LSP progress (lualine 'lsp_progress' slot)
    vim.api.nvim_create_autocmd('LspProgress', {
        group = group,
        callback = function(ev)
            local params = ev.data.params
            local value = params.value
            if type(value) ~= 'table' or not value.kind then return end
            local key = ev.data.client_id .. ':' .. tostring(params.token)
            local p = lsp_tasks[key] or {}
            p.title = value.title or p.title
            p.message = value.message or (value.kind ~= 'end' and p.message) or nil
            p.percentage = value.percentage or p.percentage
            p.time = vim.uv.now()
            p.done = value.kind == 'end'
            lsp_tasks[key] = p
            if p.done then
                -- Show the final message briefly, then remove the task
                vim.defer_fn(function()
                    if lsp_tasks[key] == p then lsp_tasks[key] = nil end
                    vim.cmd.redrawstatus()
                end, 1000)
            end
            vim.cmd.redrawstatus()
        end,
    })
    vim.api.nvim_create_autocmd('LspDetach', {
        group = group,
        callback = function(ev)
            local prefix = ev.data.client_id .. ':'
            for key in pairs(lsp_tasks) do
                if key:sub(1, #prefix) == prefix then lsp_tasks[key] = nil end
            end
            vim.cmd.redrawstatus()
        end,
    })
    -- Repaint on events that change what the line shows but don't redraw it
    vim.api.nvim_create_autocmd({ 'DiagnosticChanged', 'ModeChanged' }, {
        group = group,
        callback = function() vim.cmd.redrawstatus() end,
    })
    vim.api.nvim_create_autocmd('User', {
        group = group,
        pattern = 'GitSignsUpdate',
        callback = function() vim.cmd.redrawstatus() end,
    })
end

return M
