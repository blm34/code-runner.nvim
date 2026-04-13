if vim.g.loaded_code_runner then return end
vim.g.loaded_code_runner = true

-- ---------------------------------------------------------------------------
-- Completion
-- ---------------------------------------------------------------------------

---Return the active terminal slot numbers as completion candidates.
---@return string[]
local function complete_slots()
    local ok, state = pcall(require, "code-runner.terminal.state")
    if not ok then return {} end
    local slots = {}
    for slot in pairs(state.terminals) do
        table.insert(slots, tostring(slot))
    end
    table.sort(slots)
    return slots
end

---Return the occupied register letters that contain runnable files.
---@return string[]
local function complete_from_registers()
    local ok_core, core = pcall(require, "code-runner.executor.core")
    local ok_regs, regs = pcall(require, "code-runner.executor.registers")
    if not ok_core or not ok_regs then return {} end
    local entries = regs.get_registers_containing_filepaths(
        core.get_supported_filetypes()
    )
    local registers = {}
    for _, entry in ipairs(entries) do
        table.insert(registers, entry.reg)
    end
    return registers
end

---Return all a-z register letters as completion candidates for SaveReg.
---Occupied registers (those containing runnable files) are listed first so
---the user can see which are already in use.
---@return string[]
local function complete_save_registers()
    local occupied_set  = {}
    local occupied_list = {}

    local ok_core, core = pcall(require, "code-runner.executor.core")
    local ok_regs, regs = pcall(require, "code-runner.executor.registers")
    if ok_core and ok_regs then
        local entries = regs.get_registers_containing_filepaths(
            core.get_supported_filetypes()
        )
        for _, entry in ipairs(entries) do
            occupied_set[entry.reg] = true
            table.insert(occupied_list, entry.reg)
        end
    end

    local free = {}
    for i = string.byte("a"), string.byte("z") do
        local letter = string.char(i)
        if not occupied_set[letter] then
            table.insert(free, letter)
        end
    end

    local all = {}
    for _, r in ipairs(occupied_list) do table.insert(all, r) end
    for _, r in ipairs(free) do table.insert(all, r) end
    return all
end

-- Subcommands that accept an occupied register letter argument.
local reg_subcommands = { FromReg = true }

-- Subcommands that accept a terminal slot number argument.
local slot_subcommands = { Toggle = true, Close = true }

---Completion function for :CodeRunner.
---@param arg_lead string   the current word being completed
---@param cmd_line string   the full command line so far
---@return string[]
local function complete(arg_lead, cmd_line)
    -- Split the command line into tokens (skip the :CodeRunner part).
    local tokens = {}
    for token in cmd_line:gmatch("%S+") do
        table.insert(tokens, token)
    end
    -- tokens[1] is "CodeRunner", tokens[2] is the subcommand (may be
    -- the word currently being typed), tokens[3] is the argument.

    local subcommand = tokens[2]

    -- Completing the subcommand itself.
    if not subcommand or arg_lead == subcommand then
        local subcommands = { "FromReg", "SaveReg", "Last", "Toggle", "Close" }
        local matches = {}
        for _, s in ipairs(subcommands) do
            if s:lower():find(arg_lead:lower(), 1, true) == 1 then
                table.insert(matches, s)
            end
        end
        return matches
    end

    -- Completing the argument to a subcommand.
    if reg_subcommands[subcommand] then
        local matches = {}
        for _, r in ipairs(complete_from_registers()) do
            if r:find(arg_lead, 1, true) == 1 then
                table.insert(matches, r)
            end
        end
        return matches
    end

    if subcommand == "SaveReg" then
        local matches = {}
        for _, r in ipairs(complete_save_registers()) do
            if r:find(arg_lead, 1, true) == 1 then
                table.insert(matches, r)
            end
        end
        return matches
    end

    if slot_subcommands[subcommand] then
        local matches = {}
        for _, s in ipairs(complete_slots()) do
            if s:find(arg_lead, 1, true) == 1 then
                table.insert(matches, s)
            end
        end
        return matches
    end

    return {}
end

-- ---------------------------------------------------------------------------
-- Dispatch
-- ---------------------------------------------------------------------------

---@class CodeRunnerCommandOpts
---@field fargs string[] arguments split on whitespace
---@field bang boolean true when ! was used
---@field args string raw argument string
---@field range integer number of range items

---@param opts CodeRunnerCommandOpts
local function dispatch(opts)
    local args = opts.fargs -- table of whitespace-separated arguments
    local bang = opts.bang  -- true when ! was used
    local sub  = args[1]    -- subcommand, or nil when bare :CodeRunner

    -- :CodeRunner  /  :CodeRunner!
    -- Run the current file (bang = new terminal).
    if not sub then
        require("code-runner").run_current_file(bang)
        return
    end

    -- :CodeRunner FromReg [x]  /  :CodeRunner! FromReg [x]
    -- Run the file stored in register x (prompts if x omitted).
    if sub == "FromReg" then
        require("code-runner").run_file_from_register({
            register     = args[2] or nil,
            new_terminal = bang,
        })
        return
    end

    -- :CodeRunner SaveReg [x]
    -- Save the current file path to register x (prompts if x omitted).
    if sub == "SaveReg" then
        require("code-runner").save_current_file_path_to_register(args[2] or nil)
        return
    end

    -- :CodeRunner Last  /  :CodeRunner! Last
    -- Re-run the last command (bang = new terminal).
    if sub == "Last" then
        require("code-runner").rerun_last_command(bang)
        return
    end

    -- :CodeRunner Toggle [slot]
    -- Toggle all terminals, or a specific slot if given.
    if sub == "Toggle" then
        if args[2] then
            require("code-runner").toggle_terminal(tonumber(args[2]))
        else
            require("code-runner").toggle_all_terminals()
        end
        return
    end

    -- :CodeRunner Close [slot]
    -- Close all terminals, or a specific slot if given.
    if sub == "Close" then
        if args[2] then
            require("code-runner").close_terminal(tonumber(args[2]))
        else
            require("code-runner").close_all_terminals()
        end
        return
    end

    vim.notify(
        "[CodeRunner] Unknown subcommand: " .. sub .. ". "
        .. "Valid subcommands: FromReg, SaveReg, Last, Toggle, Close",
        vim.log.levels.WARN
    )
end

-- ---------------------------------------------------------------------------
-- Command registration
-- ---------------------------------------------------------------------------

vim.api.nvim_create_user_command("CodeRunner", dispatch, {
    bang     = true,
    nargs    = "*",
    complete = complete,
    desc     = "code-runner.nvim — run code from files",
})
