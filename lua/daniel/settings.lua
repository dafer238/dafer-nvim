-- ~/.config/nvim/lua/daniel/settings.lua

vim.g.have_nerd_font = true

vim.opt.cursorline = true
vim.opt.guicursor = {
    "n-v-c:block", -- normal, visual, command: solid block
    "i:block-blinkwait700-blinkoff400-blinkon250",
    "r-cr:hor20",  -- replace modes
    "o:hor50",
}

vim.opt.nu = true
vim.opt.relativenumber = false
vim.opt.signcolumn = 'yes'

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.swapfile = false
vim.opt.backup = false
if vim.fn.has("win32") == 1 then
    vim.opt.undodir = vim.fn.expand("$USERPROFILE") .. "\\vimfiles\\undodir"
else
    vim.opt.undodir = vim.fn.expand("$HOME") .. "/.vim/undodir"
end
vim.opt.undofile = true -- Ensure undofile is enabled

vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.inccommand = "split"

vim.opt.termguicolors = true

vim.opt.scrolloff = 7

vim.opt.updatetime = 50
vim.opt.timeoutlen = 300
vim.opt.ttimeoutlen = 10

vim.opt.colorcolumn = "100"
vim.opt.wrap = false
vim.keymap.set("n", "<leader>ww", function()
    vim.opt.wrap = not vim.opt.wrap:get()
    if vim.opt.wrap:get() then
        print("Line wrapping toggled on.")
    else
        print("Line wrapping toggled off.")
    end
end, { desc = "Toggle line wrapping" })

-- Configure LSP hover and signature help borders
vim.lsp.buf.hover = (function(original)
    return function(opts)
        opts = opts or {}
        opts.border = opts.border or 'rounded'
        return original(opts)
    end
end)(vim.lsp.buf.hover)

vim.lsp.buf.signature_help = (function(original)
    return function(opts)
        opts = opts or {}
        opts.border = opts.border or 'rounded'
        return original(opts)
    end
end)(vim.lsp.buf.signature_help)

-- User commands for vim.pack
vim.api.nvim_create_user_command("PackUpdate", function()
    vim.pack.update()
end, { desc = "Update installed packages" })

-- vim.pack never deletes a plugin just because its spec left vim.pack.add():
-- it stays on disk and in nvim-pack-lock.json, and any lockfile entry that is
-- missing on disk gets (re)installed on startup. :PackClean deletes every
-- managed plugin not added in this session, which also drops its lock entry.
vim.api.nvim_create_user_command("PackClean", function()
    local stale = {}
    for _, p in ipairs(vim.pack.get(nil, { info = false })) do
        if not p.active then stale[#stale + 1] = p.spec.name end
    end
    if #stale == 0 then
        vim.notify("vim.pack: nothing to clean")
        return
    end
    local msg = "Delete inactive plugins?\n  " .. table.concat(stale, "\n  ")
    if vim.fn.confirm(msg, "&Yes\n&No", 2) == 1 then
        vim.pack.del(stale)
    end
end, { desc = "Delete plugins no longer in vim.pack.add()" })

-- Folding configuration
vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldcolumn = "0"
vim.opt.fillchars:append({ fold = " " })
vim.o.foldtext = 'v:lua.custom_foldtext()'
vim.o.fillchars = "fold: ,foldopen: ,foldsep: ,foldclose:>"

function _G.custom_foldtext()
    -- Get the first line of the fold
    local first_line = vim.fn.getline(vim.v.foldstart)
    -- Calculate the number of folded lines
    local fold_count = vim.v.foldend - vim.v.foldstart + 1
    return first_line .. " (" .. fold_count .. " lines hidden)"
end

-- Prefer LSP folding if client supports it, otherwise fall back to treesitter
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client:supports_method('textDocument/foldingRange') then
            vim.schedule(function()
                vim.wo.foldmethod = 'expr'
                vim.wo.foldexpr = 'v:lua.vim.lsp.foldexpr()'
            end)
        end
    end
})

-- English (all regions, so "behaviour" is not flagged) + Spanish.
-- Neovim ships only English; the first time a buffer needs Spanish it offers
-- to download es.utf-8.spl into stdpath('data')/site/spell.
vim.opt.spelllang = { "en", "es" }
-- Words added with zg / zw live in this repo, so they sync between machines.
-- (The compiled *.add.spl next to it is generated and gitignored.)
vim.opt.spellfile = vim.fn.stdpath("config") .. "/spell/custom.utf-8.add"

-- Enable spell checking for common text-based filetypes
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "markdown", "text", "gitcommit", "tex" },
    callback = function()
        vim.opt.spell = true
    end,
})

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
    callback = function()
        vim.hl.on_yank()
    end,
})

-- Auto-save when leaving insert mode for specific filetypes
vim.api.nvim_create_autocmd("InsertLeave", {
    callback = function()
        -- Ensure buffer is modified, is a normal file, and has a filetype
        if vim.bo.modified and vim.bo.buftype == "" and vim.fn.expand("%:p") ~= "" and vim.bo.modifiable and not vim.bo.readonly then
            local ft = vim.bo.filetype
            local allowed_filetypes = { "python", "rust", "markdown", "go", "c", "cpp", "vim", "lua", "javascript",
                "typescript", "json" }

            if vim.tbl_contains(allowed_filetypes, ft) then
                vim.cmd("silent write") -- Auto-save
            end
        end
    end,
})

-- Auto-format on save using LSP if available (optimized)
vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup('AutoFormat', { clear = true }),
    callback = function(args)
        -- Only format if we have LSP clients attached to this buffer
        local clients = vim.lsp.get_clients({ bufnr = args.buf })
        for _, client in pairs(clients) do
            if client.server_capabilities.documentFormattingProvider then
                vim.lsp.buf.format({
                    async = false,
                    bufnr = args.buf,
                    filter = function(c)
                        return c.server_capabilities.documentFormattingProvider
                    end
                })
                break -- Only format once
            end
        end
    end,
})
