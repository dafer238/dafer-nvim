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

-- nvim-tree: quick info about the item under the cursor.
--   file:      size · modified
--   directory: total size (computed in the background) · direct children
--   link:      -> target
-- A folder's total size needs a full recursive walk, which can be slow on big
-- trees (and on Windows in general), so it runs asynchronously with libuv,
-- stops after MAX_WALK entries (shown as "≥") and is cached for CACHE_MS.
local uv = vim.uv
local MAX_WALK = 50000
local CACHE_MS = 60000
local dir_sizes = {} ---@type table<string, {size:integer, partial:boolean, time:integer}|{pending:true}>

-- Size in at most 4 characters, like `ls -h`: one decimal below 10, whole
-- numbers above, and the next unit from 1000 up (999K -> 1.0M).
-- Together with a 1-cell prefix ('≥' or ' ') the size field is always 5 cells
-- wide, so the ' · ' after it never moves while a folder size is computed.
local SIZE_W = 5

local function human(n)
    local units = { 'B', 'K', 'M', 'G', 'T' }
    local i = 1
    while n >= 999.5 and i < #units do -- 999.5 would round to "1000"
        n, i = n / 1024, i + 1
    end
    if i == 1 then return string.format('%d%s', n, units[i]) end
    if n < 9.95 then return string.format('%.1f%s', n, units[i]) end
    return string.format('%d%s', math.floor(n + 0.5), units[i])
end

-- Right-align by display cells; string.format('%5s') counts bytes and
-- '≥'/'…' are 3 bytes each
local function size_field(text)
    return string.rep(' ', math.max(0, SIZE_W - vim.fn.strdisplaywidth(text))) .. text
end

-- Recursive size of `root` without blocking: every scandir/lstat is an async
-- libuv request, `pending` counts the ones in flight, and the walk is done when
-- it drops back to 0. Symlinks are not followed (avoids cycles).
local function dir_size_async(root, on_done)
    local total, seen, pending, partial, finished = 0, 0, 0, false, false
    local function settle()
        pending = pending - 1
        if pending == 0 and not finished then
            finished = true
            on_done(total, partial)
        end
    end
    local function walk(dir)
        pending = pending + 1
        uv.fs_scandir(dir, function(err, req)
            while not err and req and not partial do
                local name, kind = uv.fs_scandir_next(req)
                if not name then break end
                seen = seen + 1
                if seen > MAX_WALK then
                    partial = true
                    break
                end
                local path = dir .. '/' .. name
                if kind == 'directory' then
                    walk(path)
                elseif kind == 'file' then
                    pending = pending + 1
                    uv.fs_lstat(path, function(_, st)
                        if st then total = total + st.size end
                        settle()
                    end)
                end
            end
            settle()
        end)
    end
    walk(root)
end

local function tree_dir_info(path)
    local count = 0
    local req = uv.fs_scandir(path)
    while req and uv.fs_scandir_next(req) do count = count + 1 end
    local items = count .. (count == 1 and ' item' or ' items')

    local c = dir_sizes[path]
    if c and c.size and uv.now() - c.time < CACHE_MS then
        return size_field((c.partial and '≥' or '') .. human(c.size)) .. ' · ' .. items
    end
    if not (c and c.pending) then
        dir_sizes[path] = { pending = true }
        dir_size_async(path, vim.schedule_wrap(function(size, partial)
            dir_sizes[path] = { size = size, partial = partial, time = uv.now() }
            vim.cmd.redrawstatus()
        end))
    end
    return size_field('…') .. ' · ' .. items
end

local function tree_node_info()
    local ok, api = pcall(require, 'nvim-tree.api')
    if not ok then return '' end
    local node = api.tree.get_node_under_cursor()
    if not node or not node.absolute_path or node.name == '..' then return '' end
    local path = node.absolute_path
    if node.type == 'directory' then return tree_dir_info(path) end
    local st = uv.fs_lstat(path)
    if not st then return '' end
    if st.type == 'link' then
        local target = uv.fs_readlink(path)
        return target and ('-> ' .. vim.fn.fnamemodify(target, ':t')) or 'link'
    end
    return size_field(human(st.size)) .. ' · ' .. os.date('%d %b %H:%M', st.mtime.sec)
end

-- Sidebar-like windows: show a label instead of file info, which is noise
-- there and does not fit in ~30 columns anyway.
local special = {
    NvimTree = '󰉋 Files',
    ['nvim-undotree'] = '󰕌 Undo tree',
    qf = '󰁨 Quickfix',
    help = '󰋖 Help',
    ['dapui_scopes'] = 'Scopes', ['dapui_breakpoints'] = 'Breakpoints',
    ['dapui_stacks'] = 'Stacks', ['dapui_watches'] = 'Watches',
    ['dap-repl'] = 'REPL', ['dapui_console'] = 'Console',
}

-- Window widths below which lower-priority parts are dropped
local W_FULL = 100 -- everything
local W_MID = 70   -- drop encoding/filetype and LSP progress
local W_MIN = 45   -- drop branch/diff and Top/Bot; mode, file, position stay

function M.render()
    local win = vim.g.statusline_winid
    local buf = vim.api.nvim_win_get_buf(win)
    local width = vim.api.nvim_win_get_width(win)
    local active = win == vim.api.nvim_get_current_win()
    local label = special[vim.bo[buf].filetype]

    if not active then
        if label then return '%#StlInactive# ' .. label end
        -- Inactive window: filename ... location
        return '%#StlInactive#%< ' .. filename(buf) .. '%=%3l:%-2v '
    end

    local m = vim.api.nvim_get_mode().mode
    local fam = mode_family(m)
    local mode = mode_names[m] or m:upper()

    if label then
        -- Mode as a single letter keeps its colour cue without eating the width
        local short = width < 40 and mode:sub(1, 1) or mode
        local a = '%#StlA_' .. fam .. '# ' .. short .. ' %#StlC#%< '
        if vim.bo[buf].filetype == 'NvimTree' then
            -- The hovered item's info replaces the label when there is one;
            -- both don't fit in the tree's width
            local info = tree_node_info()
            if info ~= '' then return a .. esc(info) end
        end
        return a .. label
    end

    local a = '%#StlA_' .. fam .. '# ' .. mode .. ' '
    local b = width >= W_MIN
        and join({ branch(buf), diff(buf), width >= W_MID and esc(progress_text()) or '' }, CSEP) or ''
    local c = join({ diagnostics(buf), filename(buf) }, CSEP)
    local x = width >= W_FULL and join({ encoding(buf), filetype(buf) }, CSEP) or ''
    local z = '%3l:%-2v'

    local left = a .. (b ~= '' and ('%#StlB# ' .. b .. ' ') or '')
    local right = (width >= W_MIN and ('%#StlB# ' .. progress(win, buf) .. ' ') or '')
        .. '%#StlA_' .. fam .. '# ' .. z .. ' '
    -- %< truncates the file section first if it still overflows, so the mode
    -- block and the cursor position are the last things to go
    return left .. '%#StlC#%< ' .. c .. '%=' .. (x ~= '' and (x .. ' ') or '') .. right
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
    -- nvim-tree: hovered item changes with the cursor
    vim.api.nvim_create_autocmd('FileType', {
        group = group,
        pattern = 'NvimTree',
        callback = function(ev)
            if vim.b[ev.buf].stl_hover then return end
            vim.b[ev.buf].stl_hover = true
            vim.api.nvim_create_autocmd('CursorMoved', {
                group = group,
                buffer = ev.buf,
                callback = function() vim.cmd.redrawstatus() end,
            })
        end,
    })
end

return M
