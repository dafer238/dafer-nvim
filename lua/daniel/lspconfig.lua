-- ~/.config/nvim/lua/daniel/lspconfig.lua

local capabilities = require('blink.cmp').get_lsp_capabilities()

-- Check if we have the new LSP API (Neovim 0.11+)
if vim.lsp.config and vim.lsp.enable then
    -- Use the new vim.lsp.config API
    -- Configure common capabilities for all servers
    vim.lsp.config('*', {
        capabilities = capabilities,
    })

    -- Define and configure individual servers using the new vim.lsp.config API
    vim.lsp.config('lua_ls', {
        cmd = { 'lua-language-server' },
        filetypes = { 'lua' },
        root_markers = { { '.luarc.json', '.luarc.jsonc' }, '.git' },
    })

    vim.lsp.config('ty', {
        cmd = { "ty", "server" },
        filetypes = { 'python' },
        root_markers = { 'pyproject.toml', 'requirements.txt', 'setup.py', '.git' },
    })

    vim.lsp.config('ruff', {
        cmd = { 'ruff', 'server', '--preview' },
        filetypes = { 'python' },
        root_markers = { 'pyproject.toml', 'ruff.toml', '.ruff.toml', '.git' },
    })

    vim.lsp.config('rust_analyzer', {
        cmd = { 'rust-analyzer' },
        filetypes = { 'rust' },
        root_markers = { 'Cargo.toml', 'rust-project.json', '.git' },
        single_file_support = true,
        settings = {
            ['rust-analyzer'] = {
                cargo = { allFeatures = true },
                procMacro = { enable = true },
                check = { command = "clippy" },
                diagnostics = { enable = true },
            },
        },
    })

    vim.lsp.config('marksman', {
        cmd = { 'marksman', 'server' },
        filetypes = { 'markdown', 'markdown.mdx' },
        root_markers = { '.marksman.toml', '.git' },
    })

    vim.lsp.config('clangd', {
        cmd = { 'clangd' },
        filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda', 'proto' },
        root_markers = { '.clangd', '.clang-tidy', '.clang-format', 'compile_commands.json', 'compile_flags.txt', 'configure.ac', '.git' },
    })

    vim.lsp.config('cssls', {
        cmd = { 'vscode-css-language-server', '--stdio' },
        filetypes = { 'css', 'scss', 'less' },
        root_markers = { 'package.json', '.git' },
    })

    vim.lsp.config('texlab', {
        cmd = { 'texlab' },
        filetypes = { 'tex', 'plaintex', 'bib' },
        root_markers = { '.latexmkrc', '.texlabroot', 'texlabroot', 'Tectonic.toml', '.git' },
    })

    -- Enable all configured servers
    local servers = { 'lua_ls', 'ty', 'ruff', 'marksman', 'clangd', 'cssls', 'texlab', 'rust_analyzer' }
    -- 'ltex',
    vim.lsp.enable(servers)
end

vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
    callback = function(event)
        -- Helper function to set mappings
        local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        -- Jump to the definition of the word under your cursor.
        map('gd', vim.lsp.buf.definition, '[G]oto [D]efinition')

        -- Find references for the word under your cursor.
        map('gr', vim.lsp.buf.references, '[G]oto [R]eferences')

        -- Jump to the implementation of the word under your cursor.
        map('gI', vim.lsp.buf.implementation, '[G]oto [I]mplementation')

        -- Go to declaration.
        map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        -- Jump to the type of the word under your cursor.
        map('<leader>D', vim.lsp.buf.type_definition, 'Type [D]efinition')

        -- List all symbols in the current document.
        map('<leader>ds', vim.lsp.buf.document_symbol, '[D]ocument [S]ymbols')

        -- List all symbols in the current workspace.
        map('<leader>ws', vim.lsp.buf.workspace_symbol, '[W]orkspace [S]ymbols')

        -- Rename the variable under your cursor.
        map('<F2>', vim.lsp.buf.rename, 'Rename variable')

        -- Execute a code action.
        map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction', { 'n', 'x' })

        -- Highlight references of the word under your cursor.
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                buffer = event.buf,
                group = highlight_augroup,
                callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                buffer = event.buf,
                group = highlight_augroup,
                callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
                group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
                callback = function(event2)
                    vim.lsp.buf.clear_references()
                    vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
                end,
            })
        end
    end,
})
