-- ~/.config/nvim/lua/daniel/plugins.lua

-- Install and load all plugins via Neovim 0.12 builtin vim.pack
vim.pack.add({
    -- LSP server installer
    'https://github.com/mason-org/mason.nvim',
    -- Completion
    { src = 'https://github.com/saghen/blink.cmp', version = vim.version.range('*') },
    -- Debugger
    'https://github.com/mfussenegger/nvim-dap',
    'https://github.com/nvim-neotest/nvim-nio',
    'https://github.com/rcarriga/nvim-dap-ui',
    -- Git integration
    'https://github.com/lewis6991/gitsigns.nvim',
    -- LaTeX support
    'https://github.com/lervag/vimtex',
    -- Treesitter (parser installation for non-bundled languages)
    'https://github.com/nvim-treesitter/nvim-treesitter',
    -- UI Enhancements
    'https://github.com/windwp/nvim-autopairs',
    'https://github.com/lukas-reineke/indent-blankline.nvim',
    'https://github.com/petertriho/nvim-scrollbar',
    { src = 'https://github.com/jake-stewart/multicursor.nvim', version = '1.0' },
    -- Fuzzy finder
    'https://github.com/nvim-tree/nvim-web-devicons',
    'https://github.com/ibhagwan/fzf-lua',
    -- File tree
    'https://github.com/kyazdani42/nvim-tree.lua',
    -- Keymap hints
    'https://github.com/folke/which-key.nvim',
    -- Statusline
    'https://github.com/nvim-lualine/lualine.nvim',
    -- Undo tree
    'https://github.com/mbbill/undotree',
    -- TODO highlighting
    'https://github.com/nvim-lua/plenary.nvim',
    'https://github.com/folke/todo-comments.nvim',
    -- Theme
    'https://github.com/sainnhe/gruvbox-material',
    -- Rust crates
    { src = 'https://github.com/saecki/crates.nvim', version = 'stable' },
})

-- Run :TSUpdate when treesitter plugin is updated
vim.api.nvim_create_autocmd('User', {
    pattern = 'PackChanged',
    callback = function()
        vim.cmd('TSUpdate')
    end,
})

-- Configure plugins after loading
require("daniel.mason")
require("daniel.treesitter")
require("daniel.blink_cmp")    -- blink.cmp uses opts, configure separately
require("gitsigns").setup()
require("nvim-autopairs").setup({ map_bs = false })
require("ibl").setup({
    indent = { char = "▏" },
    scope = { enabled = false },
})
require("scrollbar").setup({
    handle = { blend = 20, color = "#504945" },
    handlers = { gitsigns = true },
})
require("daniel.multicursor").setup()
require("daniel.fzf_lua")
require("daniel.tree")
require("which-key").setup({ preset = 'modern' })
require("daniel.statusbar")
require("daniel.undotree")
require("todo-comments").setup({})
require('daniel.theme').setup()
require('crates').setup()
