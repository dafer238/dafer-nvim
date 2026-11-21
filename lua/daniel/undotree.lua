-- ~/.config/nvim/lua/daniel/undotree.lua
-- Builtin undotree (Neovim 0.12): an opt package, loaded on first use.
-- Layout mirrors mbbill/undotree's default: tree on the left, 30 columns wide,
-- focus stays in the edited buffer.
-- Moving the cursor inside the tree window previews (undoes to) that state.

vim.keymap.set('n', '<leader>u', function()
    vim.cmd.packadd('nvim.undotree')
    local was_open = require('undotree').open({ command = 'topleft 30vnew' })
    if not was_open then
        vim.cmd.wincmd('p') -- return focus to the edited buffer
    end
end, { desc = "Toggle undo tree" })
