-- ~/.config/nvim/lua/daniel/tree.lua

-- h/l navigation on top of the default mappings:
--   l: expand a folder / open a file (same as <CR>, but never collapses)
--   h: collapse the hovered folder if it is open, otherwise collapse the
--      folder that contains it and move there. Repeating h walks up and
--      collapses everything.
local function on_attach(bufnr)
    local api = require("nvim-tree.api")
    api.config.mappings.default_on_attach(bufnr)

    local function opts(desc)
        return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
    end

    vim.keymap.set("n", "l", function()
        local node = api.tree.get_node_under_cursor()
        if not node then return end
        if node.type == "directory" and node.open then return end
        api.node.open.edit()
    end, opts("Expand folder / open file"))

    vim.keymap.set("n", "h", function()
        local node = api.tree.get_node_under_cursor()
        if not node then return end
        if node.type == "directory" and node.open then
            api.node.open.edit() -- toggles: collapses this folder
        else
            api.node.navigate.parent_close()
        end
    end, opts("Collapse folder / parent folder"))
end

require("nvim-tree").setup({
    on_attach = on_attach,
    sync_root_with_cwd = true,
    reload_on_bufenter = true,
    view = {
        width = 30,
        side = "left",
    },
    filters = {
        dotfiles = false,
        git_ignored = false
    },
    renderer = {
        highlight_git = true,
        icons = {
            show = {
                file = true,
                folder = true,
                folder_arrow = true,
                git = true
            },
        },
        indent_markers = {
            enable = true,
        },
    },
    actions = {
        open_file = {
            quit_on_open = true,
        }
    }
})

-- Keymap to toggle the tree view
vim.keymap.set("n", "<leader>t", function()
    -- Toggle the Nvim-Tree
    vim.cmd("NvimTreeToggle")
end, {
    desc = "Toggle file tree",
    silent = true,
    noremap = true
})
