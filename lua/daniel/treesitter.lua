-- ~/.config/nvim/lua/daniel/treesitter.lua

-- Install non-bundled parsers (c, lua, vim, vimdoc, query, markdown, markdown_inline are bundled with Neovim 0.12)
require('nvim-treesitter').install {
    "bash",
    "diff",
    "html",
    "luadoc",
    "python",
    "rust",
    "javascript",
    "typescript",
    "json",
    "zig",
    "regex",
    "gitignore",
    "toml",
    "latex",
}

-- Enable treesitter highlighting via builtin API
vim.api.nvim_create_autocmd('FileType', {
    pattern = {
        "bash", "sh", "c", "cpp", "css", "diff", "html", "json",
        "lua", "luadoc", "markdown", "markdown_inline", "python",
        "rust", "javascript", "typescript", "vim", "vimdoc", "query",
        "zig", "regex", "gitignore", "toml", "latex", "tex",
    },
    callback = function()
        vim.treesitter.start()
    end,
})
