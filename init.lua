-- ~/.config/nvim/init.lua

-- Disable built-in plugins early for faster startup
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_gzip = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_rrhelper = 1

-- Set leaders early
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load core settings first (before plugins)
require("daniel.settings")

-- Install and load plugins via builtin vim.pack
require("daniel.plugins")

-- Load other configurations after plugins
require('daniel.diagnostics')
require('daniel.lspconfig')
require('daniel.run')
require('daniel.debug')
require("daniel.mappings")

-- Enable Neovim 0.12 experimental UI (replaces noice.nvim)
require('vim._extui').enable({})

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
