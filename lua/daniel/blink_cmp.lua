-- ~/.config/nvim/lua/daniel/blink_cmp.lua

require('blink.cmp').setup({
    keymap = { preset = 'super-tab' },
    appearance = {
        nerd_font_variant = 'mono'
    },
    cmdline = {
        keymap = {
            preset = 'super-tab'
        },
        completion = { menu = { auto_show = true } },
    },
    completion = {
        keyword = { range = 'prefix' },
        list = {
            selection = { preselect = true, auto_insert = false } },

        menu = {
            draw = {
                treesitter = { 'lsp' },
                columns = {
                    { "label",     "label_description", gap = 1 },
                    { "kind_icon", "kind" }
                },
            },
            border = 'rounded',
            scrollbar = false,
        },
        documentation = {
            auto_show = true,
            auto_show_delay_ms = 500,
            treesitter_highlighting = true,
            window = { border = 'rounded' }
        },

        ghost_text = { enabled = false },
    },
    sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
    },
})
