-- ~/.config/nvim/lua/daniel/mason.lua

require("mason").setup()

-- Auto-install LSP server binaries on startup.
-- Maps vim.lsp.config server names → Mason package names.
local ensure_installed = {
    "lua-language-server", -- lua_ls
    "ruff",                -- ruff
    "rust-analyzer",       -- rust_analyzer
    "marksman",            -- marksman
    "clangd",              -- clangd
    "css-lsp",             -- cssls
    "texlab",              -- texlab
    "ty",                  -- ty
    "ruff",                -- ruff
}

local registry = require("mason-registry")
registry.refresh(function()
    for _, name in ipairs(ensure_installed) do
        local ok, pkg = pcall(registry.get_package, name)
        if ok and not pkg:is_installed() then
            pkg:install()
            vim.notify("Mason: Installing " .. name, vim.log.levels.INFO)
        end
    end
end)
