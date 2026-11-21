-- ~/.config/nvim/lua/daniel/treesitter.lua
--
-- Highlighting, folds and injections are done by Neovim itself (vim.treesitter).
-- Neovim only bundles parsers + queries for: c, lua, markdown, markdown_inline,
-- query, vim, vimdoc. Everything else needs a compiled parser (parser/<lang>.so)
-- AND query files (queries/<lang>/*.scm); a parser alone gives no highlighting.
--
-- nvim-treesitter (`main` branch) is used only as an installer for those two
-- pieces. It requires the tree-sitter CLI (>= 0.26.1) and a C compiler.
-- Parsers are installed to stdpath('data')/site, which is on 'runtimepath'.

-- Parsers to install (bundled ones are left to Neovim).
-- latex is left out on purpose: vimtex provides tex highlighting and
-- recommends against treesitter for it.
local parsers = {
    "bash", "cpp", "css", "diff", "html", "javascript", "json", "luadoc",
    "python", "regex", "rust", "toml", "typescript", "zig", "gitignore",
}

-- Install only what is missing, after startup, so launch is never blocked.
vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
        local missing = {}
        for _, lang in ipairs(parsers) do
            if #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) == 0 then
                missing[#missing + 1] = lang
            end
        end
        if #missing > 0 then
            require("nvim-treesitter").install(missing)
        end
    end,
})

-- Enable treesitter highlighting via builtin API
vim.api.nvim_create_autocmd('FileType', {
    pattern = {
        "bash", "sh", "c", "cpp", "css", "diff", "html", "json",
        "lua", "luadoc", "markdown", "markdown_inline", "python",
        "rust", "javascript", "typescript", "vim", "vimdoc", "query",
        "zig", "regex", "gitignore", "toml",
        -- tex is left to vimtex's syntax on purpose: it marks commands, labels,
        -- refs and cite keys as no-spell, which treesitter's latex queries do
        -- not, and vimtex's motions/text objects rely on it.
    },
    callback = function()
        pcall(vim.treesitter.start)
    end,
})
