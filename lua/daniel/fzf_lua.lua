-- ~/.config/nvim/lua/daniel/fzf-lua.lua

local status, fzf = pcall(require, 'fzf-lua')
if not status then
    vim.notify('fzf-lua is not installed', vim.log.levels.ERROR)
    return
end

fzf.setup({
    winopts = {
        height   = 0.85,
        width    = 0.80,
        preview  = {
            layout = 'horizontal',
        },
        border   = "rounded",
        backdrop = 60,
    },
    keymap = {
        builtin = {
            ['<esc>'] = 'abort',
        },
        fzf = {
            ['tab'] = 'down',         -- Tab navigates down
            ['btab'] = 'up',          -- S-Tab navigates up
            ['left'] = 'toggle+down', -- Left arrow untoggles and moves down
            ['right'] = 'toggle+up',  -- Right arrow untoggles and moves up
            ['down'] = 'down',        -- Up arrow for navigating up
            ['up'] = 'up',            -- Down arrow for navig'shift-tab:up'ating down
        },
    },
    -- files = { no_ignore = true },
    -- grep = { no_ignore = true },

    fzf_opts = {
    },
})

-- Helper function for custom directory search
local function fzf_files_in_dir(dir)
    return function()
        fzf.files({ cwd = dir })
    end
end

-- Keymaps
vim.keymap.set('n', '<leader>sh', fzf.help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sk', fzf.keymaps, { desc = '[S]earch [K]eymaps' })
vim.keymap.set('n', '<leader>sf', fzf.files, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>ss', fzf.builtin, { desc = '[S]earch [S]elect fzf-lua' })
vim.keymap.set('n', '<leader>sw', fzf.grep_cword, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', fzf.live_grep, { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', 'g/', fzf.live_grep, { desc = '[S]earch by [G]rep' })
-- vim.keymap.set('n', '<leader>sd', fzf.diagnostics, { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sr', fzf.resume, { desc = '[S]earch [R]esume' })
vim.keymap.set('n', '<leader>s.', fzf.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
vim.keymap.set('n', '<leader><leader>', fzf.buffers, { desc = '[ ] Find existing buffers' })

-- Shortcut for searching your Neovim configuration files
vim.keymap.set('n', '<leader>sn', fzf_files_in_dir(vim.fn.stdpath('config')), { desc = '[S]earch [N]eovim files' })

-- Fuzzy find in the current buffer
vim.keymap.set({ 'n', 'x', 'v' }, '<C-f>', function()
    fzf.blines({
        winopts = {
            height = 0.5,
            width = 0.80,
            preview = { hidden = 'hidden' },
        },
        actions = {
            ["default"] = function(selected, opts)
                -- First, run the builtin default action (jump to line)
                fzf.actions.file_edit(selected, opts) -- works for blines too

                -- Then, set the search register based on the fzf query
                if opts and opts.query and #opts.query > 0 then
                    -- Use the fuzzy query, so `n/N` cycles through matches
                    vim.fn.setreg("/", vim.fn.escape(opts.query, "\\/"))
                    vim.cmd("normal! n")
                end
            end,
        },
    })
end, { desc = '[/] Fuzzily search in current buffer' })
