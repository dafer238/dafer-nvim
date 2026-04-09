-- ~/.config/nvim/lua/daniel/ui.lua
-- Native UI overrides: navigable vim.ui.select + long-message viewer

-----------------------------------------------------------
-- 1. Custom vim.ui.select — floating window with j/k nav
-----------------------------------------------------------

vim.ui.select = function(items, opts, on_choice)
    opts = opts or {}
    if not items or #items == 0 then
        on_choice(nil, nil)
        return
    end

    local format_item = opts.format_item or tostring
    local prompt = opts.prompt or "Select:"
    -- Remove trailing colon/space for cleaner title
    prompt = prompt:gsub("[:%s]+$", "")

    -- Build display lines
    local lines = {}
    for i, item in ipairs(items) do
        lines[i] = format_item(item)
    end

    -- Calculate window dimensions
    local max_width = #prompt
    for _, line in ipairs(lines) do
        max_width = math.max(max_width, #line + 4) -- account for "▸ " prefix + padding
    end
    local width = math.min(math.max(max_width + 2, 30), math.floor(vim.o.columns * 0.6))
    local height = math.min(#items, math.floor(vim.o.lines * 0.5))

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = " " .. prompt .. " ",
        title_pos = 'center',
    })
    vim.wo[win].cursorline = false
    vim.wo[win].wrap = false

    local ns = vim.api.nvim_create_namespace('ui_select')
    local idx = 1
    local closed = false

    local function render()
        vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
        local display = {}
        for i, line in ipairs(lines) do
            if i == idx then
                display[i] = "  ▸ " .. line
            else
                display[i] = "    " .. line
            end
        end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, display)
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        vim.api.nvim_buf_add_highlight(buf, ns, 'PmenuSel', idx - 1, 0, -1)
        vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
    end

    local function close(choice_idx)
        if closed then return end
        closed = true
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
        if choice_idx then
            on_choice(items[choice_idx], choice_idx)
        else
            on_choice(nil, nil)
        end
    end

    local function move(delta)
        idx = idx + delta
        if idx < 1 then idx = 1 end
        if idx > #items then idx = #items end
        render()
    end

    render()

    -- Keymaps (buffer-local)
    local map_opts = { buffer = buf, nowait = true, noremap = true, silent = true }

    vim.keymap.set('n', 'j', function() move(1) end, map_opts)
    vim.keymap.set('n', 'k', function() move(-1) end, map_opts)
    vim.keymap.set('n', '<Down>', function() move(1) end, map_opts)
    vim.keymap.set('n', '<Up>', function() move(-1) end, map_opts)
    vim.keymap.set('n', '<CR>', function() close(idx) end, map_opts)
    vim.keymap.set('n', '<Esc>', function() close(nil) end, map_opts)
    vim.keymap.set('n', 'q', function() close(nil) end, map_opts)

    -- Number keys for quick select (1-9)
    for i = 1, math.min(9, #items) do
        vim.keymap.set('n', tostring(i), function() close(i) end, map_opts)
    end

    -- Close if window loses focus
    vim.api.nvim_create_autocmd('WinLeave', {
        buffer = buf,
        once = true,
        callback = function()
            close(nil)
        end,
    })
end

-----------------------------------------------------------
-- 2. Long-message viewer — float for messages > threshold
-----------------------------------------------------------

local original_notify = vim.notify
local MSG_LINE_THRESHOLD = 3

vim.notify = function(msg, level, notify_opts)
    if type(msg) ~= "string" then
        original_notify(msg, level, notify_opts)
        return
    end

    local line_count = select(2, msg:gsub("\n", "\n")) + 1

    if line_count <= MSG_LINE_THRESHOLD then
        original_notify(msg, level, notify_opts)
        return
    end

    -- Show long message in a floating window
    local msg_lines = vim.split(msg, "\n")
    local max_line = 0
    for _, line in ipairs(msg_lines) do
        max_line = math.max(max_line, #line)
    end

    local width = math.min(math.max(max_line + 2, 40), math.floor(vim.o.columns * 0.8))
    local height = math.min(#msg_lines, math.floor(vim.o.lines * 0.7))

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, msg_lines)
    vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })

    local level_titles = {
        [vim.log.levels.ERROR] = " Error ",
        [vim.log.levels.WARN] = " Warning ",
        [vim.log.levels.INFO] = " Info ",
        [vim.log.levels.DEBUG] = " Debug ",
        [vim.log.levels.TRACE] = " Trace ",
    }
    local title = level_titles[level] or " Message "

    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = title,
        title_pos = 'center',
    })
    vim.wo[win].wrap = true

    local map_opts = { buffer = buf, nowait = true, noremap = true, silent = true }
    local closed = false
    local function close_win()
        if closed then return end
        closed = true
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    vim.keymap.set('n', 'q', close_win, map_opts)
    vim.keymap.set('n', '<Esc>', close_win, map_opts)
    vim.keymap.set('n', '<CR>', close_win, map_opts)

    vim.api.nvim_create_autocmd('WinLeave', {
        buffer = buf,
        once = true,
        callback = close_win,
    })
end
