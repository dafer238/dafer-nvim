-- ~/.config/nvim/lua/daniel/run.lua

-- Native floating terminal helper (replaces toggleterm)
local function run_in_floating_terminal(cmd, wd)
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2),
        style = 'minimal',
        border = 'rounded',
    })
    vim.wo[win].winblend = 10

    if wd then
        if vim.fn.has('win32') == 1 then
            cmd = 'cd /d "' .. wd .. '" && ' .. cmd
        else
            cmd = 'cd "' .. wd .. '" && ' .. cmd
        end
    end
    vim.fn.termopen(cmd, {
        on_exit = function()
            -- Keep buffer open so user can read output (close_on_exit = false equivalent)
        end,
    })
    vim.cmd('startinsert')
end

-- Toggleable floating terminal (replaces <C-\> ToggleTerm)
local toggle_term_buf = nil
local toggle_term_win = nil

local function toggle_floating_terminal()
    if toggle_term_win and vim.api.nvim_win_is_valid(toggle_term_win) then
        vim.api.nvim_win_hide(toggle_term_win)
        toggle_term_win = nil
        return
    end

    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local opts = {
        relative = 'editor',
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2),
        style = 'minimal',
        border = 'rounded',
    }

    if toggle_term_buf and vim.api.nvim_buf_is_valid(toggle_term_buf) then
        toggle_term_win = vim.api.nvim_open_win(toggle_term_buf, true, opts)
        vim.cmd('startinsert')
    else
        toggle_term_buf = vim.api.nvim_create_buf(false, true)
        toggle_term_win = vim.api.nvim_open_win(toggle_term_buf, true, opts)
        vim.fn.termopen(vim.o.shell)
        vim.cmd('startinsert')
    end
end

vim.keymap.set({ 'n', 't' }, '<C-\\>', toggle_floating_terminal, { desc = "Toggle terminal", silent = true })

-- Generates a safe display echo command (shows >> prefix, avoids redirect on cmd.exe)
local function cmd_echo(label)
    if vim.fn.has('win32') == 1 then
        local shell = vim.o.shell:lower()
        if not (shell:find("powershell") or shell:find("pwsh")) then
            -- cmd.exe: escape shell metacharacters so they display literally
            local escaped = label:gsub("&&", "^&^&"):gsub(">", "^>"):gsub("<", "^<"):gsub("|", "^|")
            return "echo ^>^> " .. escaped
        end
    end
    return "echo '>> " .. label .. "\\n'"
end

local run_script = function(rust_mode, zig_mode)
    local current_cwd = vim.fn.getcwd()
    local filepath = vim.fn.expand("%:p")   -- Full path
    local filedir = vim.fn.expand("%:p:h")
    local filename = vim.fn.expand("%:t:r") -- Filename without extension
    local filename_ext = vim.fn.expand("%:t") -- Filename with extension
    local filetype = vim.bo.filetype
    local is_check = (rust_mode == 'check')
    local is_win = vim.fn.has('win32') == 1

    local is_rust_project = vim.fn.filereadable(current_cwd .. "/Cargo.toml") == 1
    local is_zig_project = vim.fn.filereadable(current_cwd .. "/build.zig") == 1
    local is_c_project = vim.fn.filereadable(current_cwd .. "/Makefile") == 1

    -- Get first target from Makefile (excluding .PHONY)
    local function get_makefile_target()
        local makefile_path = current_cwd .. "/Makefile"
        local lines = vim.fn.readfile(makefile_path)
        for _, line in ipairs(lines) do
            local target = line:match("^([%w%._-]+):")
            if target and target ~= ".PHONY" then
                return target
            end
        end
        return nil
    end

    -- Compile single C/C++ file with clang/gcc
    local function compile_single_c_file()
        local compiler = filetype == "c" and "clang" or "clang++"
        vim.cmd("silent write")

        local display, run_cmd
        if is_check then
            display  = compiler .. " -fsyntax-only " .. filename_ext
            run_cmd  = compiler .. ' -fsyntax-only "' .. filename_ext .. '"'
        else
            local output = filename .. "_out" .. (is_win and ".exe" or "")
            local run_output = (is_win and ".\\" or "./") .. output
            display  = compiler .. " " .. filename_ext .. " -o " .. output .. " && " .. run_output
            run_cmd  = compiler .. ' "' .. filename_ext .. '" -o ' .. output .. " && " .. run_output
        end

        run_in_floating_terminal(cmd_echo(display) .. " && " .. run_cmd, filedir)
    end

    -- Prompt user for C/C++ compilation choice
    local function c_compile_choice()
        local action = is_check and "Check" or "Compile"
        vim.ui.select({ "Project (Makefile)", "Single file" }, {
            prompt = action .. " C/C++ project or single file?",
            format_item = function(item) return item end,
        }, function(choice)
            if choice == "Project (Makefile)" then
                local target = get_makefile_target()
                local make_cmd = target and ("make " .. target) or "make"
                local cmd = cmd_echo(make_cmd .. " (" .. current_cwd .. ")") .. " && " .. make_cmd
                run_in_floating_terminal(cmd, current_cwd)
            elseif choice == "Single file" then
                compile_single_c_file()
            else
                vim.notify("Cancelled compilation.", vim.log.levels.INFO)
            end
        end)
    end

    local function get_rust_binaries()
        local bins = {}
        local cargo_toml_path = current_cwd .. "/Cargo.toml"

        if vim.fn.filereadable(cargo_toml_path) == 0 then
            return bins
        end

        local lines = vim.fn.readfile(cargo_toml_path)
        local is_workspace = false
        local members = {}
        local in_members_list = false
        local in_bin_table = false
        local current_bin = {}

        for _, line in ipairs(lines) do
            -- Detect workspace members
            if line:match("^%[workspace%]") then
                is_workspace = true
            elseif is_workspace and line:match("^members%s*=") then
                if line:match("%[") and line:match("%]") then
                    for member in line:gmatch('"(.-)"') do
                        table.insert(members, member)
                    end
                else
                    in_members_list = true
                    for member in line:gmatch('"(.-)"') do
                        table.insert(members, member)
                    end
                end
            elseif in_members_list then
                for member in line:gmatch('"(.-)"') do
                    table.insert(members, member)
                end
                if line:match("%]") then
                    in_members_list = false
                end

                -- Detect [bin] array-style tables
            elseif line:match("^{%s*name%s*=") or line:match("^%s*{") then
                local name = line:match('name%s*=%s*"(.-)"')
                if name then
                    table.insert(bins, name)
                end

                -- Detect TOML-style [[bin]] tables
            elseif line:match("^%[%[bin%]%]") then
                in_bin_table = true
                current_bin = {}
            elseif in_bin_table then
                local name = line:match('^name%s*=%s*"(.-)"')
                if name then
                    current_bin.name = name
                end
                if line:match("^path%s*=%s*") or line:match("^name%s*=%s*") then
                    -- When both name and path appear, finalize
                    if current_bin.name then
                        table.insert(bins, current_bin.name)
                        current_bin = {}
                        in_bin_table = false
                    end
                end
            end
        end

        if not is_workspace then
            members = { "." }
        end

        -- Add standard src/main.rs and src/bin/*.rs detection too
        for _, member in ipairs(members) do
            local member_path = member == "." and current_cwd or (current_cwd .. "/" .. member)
            local crate_name = vim.fn.fnamemodify(member_path, ":t")

            if vim.fn.filereadable(member_path .. "/src/main.rs") == 1 then
                table.insert(bins, crate_name)
            end

            local bin_files = vim.fn.globpath(member_path .. "/src/bin", "*.rs", false, true)
            for _, f in ipairs(bin_files) do
                local bn = vim.fn.fnamemodify(f, ":t:r")
                table.insert(bins, bn)
            end
        end

        return vim.fn.uniq(bins)
    end

    local function run_rust_project()
        local bins = get_rust_binaries()
        local file_path = vim.fn.expand("%:p")

        -- Try to auto-detect which bin corresponds to current file
        local auto_bin = nil
        for _, bin in ipairs(bins) do
            if file_path:find(bin .. "%.rs$") then
                auto_bin = bin
                break
            end
        end

        if auto_bin then
            local bin_cmd = string.format("cargo %s --bin %s", rust_mode, auto_bin)
            local cmd = cmd_echo(bin_cmd .. " (" .. current_cwd .. ")") .. " && " .. bin_cmd
            run_in_floating_terminal(cmd, current_cwd)
        elseif #bins > 1 then
            vim.ui.select(bins, {
                prompt = "Select Rust binary to " .. rust_mode .. ":",
                format_item = function(item) return item end,
            }, function(choice)
                if choice then
                    local bin_cmd = string.format("cargo %s --bin %s", rust_mode, choice)
                    local cmd = cmd_echo(bin_cmd .. " (" .. current_cwd .. ")") .. " && " .. bin_cmd
                    run_in_floating_terminal(cmd, current_cwd)
                else
                    vim.notify("Cancelled Rust run.", vim.log.levels.INFO)
                end
            end)
        else
            local cargo_cmd = "cargo " .. rust_mode
            local cmd = cmd_echo(cargo_cmd .. " (" .. current_cwd .. ")") .. " && " .. cargo_cmd
            run_in_floating_terminal(cmd, current_cwd)
        end
    end

    local ran = false -- Track if we ran anything

    -- Handle C/C++ files with prompt if Makefile exists
    if (filetype == "c" or filetype == "cpp") and filepath ~= "" and vim.bo.buftype == "" then
        vim.cmd("silent write") -- Save file

        if is_c_project then
            c_compile_choice()
            ran = true
        else
            compile_single_c_file()
            ran = true
        end
    end

    -- Attempt to run directly if it's a script
    if not ran and filepath ~= "" and vim.bo.buftype == "" then
        vim.cmd("silent write") -- Save file

        local display, run_cmd
        if filetype == "python" then
            if is_check then
                display  = "ruff check " .. filename_ext
                run_cmd  = 'ruff check "' .. filename_ext .. '"'
            else
                display  = "python " .. filename_ext
                run_cmd  = 'python "' .. filename_ext .. '"'
            end
        elseif filetype == "lua" then
            display = "lua " .. filename_ext
            run_cmd = 'lua "' .. filename_ext .. '"'
        elseif filetype == "javascript" then
            display = "node " .. filename_ext
            run_cmd = 'node "' .. filename_ext .. '"'
        elseif filetype == "typescript" then
            display = "ts-node " .. filename_ext
            run_cmd = 'ts-node "' .. filename_ext .. '"'
        end

        if run_cmd then
            run_in_floating_terminal(cmd_echo(display) .. " && " .. run_cmd, filedir)
            ran = true
        end
    end

    -- Fallback to project-level runners
    if not ran then
        if is_rust_project then
            run_rust_project()
            ran = true
        elseif is_zig_project then
            local zig_cmd = "zig " .. zig_mode
            local cmd = cmd_echo(zig_cmd .. " (" .. current_cwd .. ")") .. " && " .. zig_cmd
            run_in_floating_terminal(cmd, current_cwd)
            ran = true
        elseif is_c_project then
            local target = get_makefile_target()
            local make_cmd = target and ("make " .. target) or "make"
            local cmd = cmd_echo(make_cmd .. " (" .. current_cwd .. ")") .. " && " .. make_cmd
            run_in_floating_terminal(cmd, current_cwd)
            ran = true
        end
    end

    if not ran then
        vim.notify("Cannot run script: unsupported filetype and no known project type", vim.log.levels.ERROR)
    end
end

vim.keymap.set({ "n", "v", "x" }, "<leader>r", function() run_script('run', 'build run') end,
    { desc = "Save and run current script in terminal." })

vim.keymap.set({ "n", "v", "x" }, "<leader>R", function() run_script('check', 'build test') end,
    { desc = "Save and check current script in terminal." })
