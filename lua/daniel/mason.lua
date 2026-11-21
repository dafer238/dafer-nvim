-- ~/.config/nvim/lua/daniel/mason.lua

-- setup() only prepends Mason's bin directory to $PATH; it is cheap.
require("mason").setup()

-- Mason package name -> executable it provides (the `cmd` used in lspconfig.lua)
local ensure_installed = {
    ["lua-language-server"] = "lua-language-server", -- lua_ls
    ["ruff"]                = "ruff",                -- ruff
    ["rust-analyzer"]       = "rust-analyzer",       -- rust_analyzer
    ["marksman"]            = "marksman",            -- marksman
    ["clangd"]              = "clangd",              -- clangd
    ["css-lsp"]             = "vscode-css-language-server", -- cssls
    ["texlab"]              = "texlab",              -- texlab
    ["ty"]                  = "ty",                  -- ty
}

-- Install the given packages (refreshes the registry once, asynchronously)
local function install(names)
    local registry = require("mason-registry")
    registry.refresh(function()
        for _, name in ipairs(names) do
            local ok, pkg = pcall(registry.get_package, name)
            if ok and not pkg:is_installed() then
                pkg:install()
                vim.notify("Mason: Installing " .. name, vim.log.levels.INFO)
            end
        end
    end)
end

-- On startup, only touch the registry when a server binary is missing from
-- $PATH (Mason's bin dir or the system). Checking $PATH is a few stat calls;
-- refreshing the registry on every launch was the expensive part.
local missing = {}
for pkg, exe in pairs(ensure_installed) do
    if vim.fn.executable(exe) == 0 then
        missing[#missing + 1] = pkg
    end
end
if #missing > 0 then
    install(missing)
end

-- Force a check of every package, regardless of what is on $PATH
vim.api.nvim_create_user_command("MasonEnsure", function()
    install(vim.tbl_keys(ensure_installed))
end, { desc = "Install missing Mason packages" })
