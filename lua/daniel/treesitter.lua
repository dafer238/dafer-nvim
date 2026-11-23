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

local function missing_parsers()
    local missing = {}
    for _, lang in ipairs(parsers) do
        if #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) == 0 then
            missing[#missing + 1] = lang
        end
    end
    return missing
end

local function install_missing()
    local missing = missing_parsers()
    if #missing > 0 then
        require("nvim-treesitter").install(missing)
    end
end

-- Install only what is missing, after startup, so launch is never blocked.
-- Without the tree-sitter CLI every parser fails with "ENOENT ... 'tree-sitter'",
-- so wait for Mason (see mason.lua) to install it and continue from there.
vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
        if #missing_parsers() == 0 then return end
        if vim.fn.executable("tree-sitter") == 1 then
            install_missing()
            return
        end
        vim.notify("treesitter: waiting for Mason to install tree-sitter-cli before compiling parsers",
            vim.log.levels.WARN)
        require("mason-registry"):on("package:install:success", vim.schedule_wrap(function(pkg)
            if pkg.name == "tree-sitter-cli" then install_missing() end
        end))
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
