-- ~/.config/nvim/lua/daniel/plugins.lua

-- Plugin build hooks. Must be defined before vim.pack.add() so they also run
-- on first install. PackChanged is a real event in 0.12 (not a User event).
vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
        local name, kind = ev.data.spec.name, ev.data.kind
        -- Keep installed parsers in sync with nvim-treesitter's pinned revisions
        if name == 'nvim-treesitter' and kind == 'update' then
            if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
            vim.cmd('TSUpdate')
        end
    end,
})

-- Install and load all plugins via Neovim 0.12 builtin vim.pack
vim.pack.add({
    -- LSP server installer
    'https://github.com/mason-org/mason.nvim',
    -- Completion
    { src = 'https://github.com/saghen/blink.cmp',              version = vim.version.range('*') },
    -- Treesitter parser + query installer (highlighting itself is builtin)
    { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' },
    -- Debugger
    'https://github.com/mfussenegger/nvim-dap',
    'https://github.com/nvim-neotest/nvim-nio',
    'https://github.com/rcarriga/nvim-dap-ui',
    -- Git integration
    'https://github.com/lewis6991/gitsigns.nvim',
    -- LaTeX support
    'https://github.com/lervag/vimtex',
    -- UI Enhancements
    'https://github.com/windwp/nvim-autopairs',
    { src = 'https://github.com/jake-stewart/multicursor.nvim', version = '1.0' },
    -- Fuzzy finder
    'https://github.com/nvim-tree/nvim-web-devicons',
    'https://github.com/ibhagwan/fzf-lua',
    -- File tree
    'https://github.com/kyazdani42/nvim-tree.lua',
    -- Keymap hints
    'https://github.com/folke/which-key.nvim',
    -- Theme
    'https://github.com/sainnhe/gruvbox-material',
    -- Rust crates
    { src = 'https://github.com/saecki/crates.nvim', version = 'stable' },
})

-- Configure plugins after loading
require("daniel.mason")
require("daniel.treesitter")
require("daniel.blink_cmp") -- blink.cmp uses opts, configure separately
require("gitsigns").setup()
require("nvim-autopairs").setup({ map_bs = false })
require("daniel.multicursor").setup()
require("daniel.fzf_lua")
require("daniel.tree")
require("which-key").setup({ preset = 'modern' })
require('daniel.theme').setup()
require('crates').setup()

-- Native replacements for former plugins
require("daniel.statusbar").setup() -- lualine
require("daniel.indent_guides")     -- indent-blankline
require("daniel.undotree")          -- mbbill/undotree
require("daniel.todo")              -- todo-comments
