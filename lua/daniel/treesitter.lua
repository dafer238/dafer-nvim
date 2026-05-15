-- ~/.config/nvim/lua/daniel/treesitter.lua

-- Neovim 0.12 bundles parsers for: bash, c, diff, html, javascript, json, lua,
-- luadoc, markdown, markdown_inline, python, query, regex, typescript, vim, vimdoc.
-- Non-bundled parsers (zig, gitignore, toml, latex, rust, etc.) will silently skip
-- treesitter highlighting. Install them via the tree-sitter CLI if needed:
--   tree-sitter build --output ~/.local/share/nvim/parser/<lang>.so

-- Enable treesitter highlighting via builtin API
vim.api.nvim_create_autocmd('FileType', {
    pattern = {
        "bash", "sh", "c", "cpp", "css", "diff", "html", "json",
        "lua", "luadoc", "markdown", "markdown_inline", "python",
        "rust", "javascript", "typescript", "vim", "vimdoc", "query",
        "zig", "regex", "gitignore", "toml", "latex", "tex",
    },
    callback = function()
        pcall(vim.treesitter.start)
    end,
})
