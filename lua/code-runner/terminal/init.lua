local M = {}

---@alias BusyTerminalOptions "Cancel" | "Interrupt terminal" | "Open new terminal"

---Handle the user's choice when all terminals are busy
---@param cmd string
---@return fun(choice: BusyTerminalOptions)
local function on_all_busy_choice(cmd)
    return function(choice)
        if not choice or choice == "Cancel" then
            return
        elseif choice == "Interrupt terminal" then
            local first_slot = require("code-runner.terminal.state").first_slot()
            if first_slot then
                require("code-runner.terminal.commands").interrupt_and_run(first_slot, cmd)
                vim.notify("[CodeRunner] Terminal " .. first_slot .. " interrupted", vim.log.levels.INFO)
            end
        elseif choice == "Open new terminal" then
            require("code-runner.terminal.commands").run_in_new_slot(cmd)
        end
    end
end

---Run a command, automatically selecting the best terminal
---@param cmd string
function M.run(cmd)
    local config = require("code-runner.config")
    local state = require("code-runner.terminal.state")

    local count = state.terminal_count()

    -- no terminals yet - create one
    if count == 0 then
        require("code-runner.terminal.commands").send(state.next_slot(), cmd)
        return
    end

    -- find the first idle terminal
    local idle_slot = state.first_idle_slot()
    if idle_slot then
        require("code-runner.terminal.commands").send(idle_slot, cmd)
        return
    end

    -- all terminals are busy
    if config.options.busy_behaviour == "cancel" then
        vim.notify("[CodeRunner] No free terminal - Command cancelled", vim.log.levels.INFO)
        return
    elseif config.options.busy_behaviour == "interrupt" then
        on_all_busy_choice(cmd)("Interrupt terminal")
        return
    elseif config.options.busy_behaviour == "new" then
        on_all_busy_choice(cmd)("Open new terminal")
        return
    end

    vim.ui.select(
        { "Cancel", "Interrupt terminal", "Open new terminal" },
        { prompt = "All terminals are busy:" },
        on_all_busy_choice(cmd)
    )
end

---Run a command in a brand new terminal slot
---@param cmd string
function M.run_in_new_terminal(cmd)
    require("code-runner.terminal.commands").run_in_new_slot(cmd)
end

---Get a single character (digit) input from the user
---@return integer?
local function terminal_slot_input()
    vim.api.nvim_echo({ { "Enter terminal slot: ", "Normal" } }, false, {})
    local char = vim.fn.getcharstr()
    local num = tonumber(char)
    if not num or num < 1 then
        vim.notify("[CodeRunner] Invalid slot: " .. char, vim.log.levels.WARN)
        return nil
    end
    return num
end

---Toggle the given terminal's visibility
---@param slot integer?
function M.toggle(slot)
    slot = slot or terminal_slot_input()
    if not slot then return end
    local term = require("code-runner.terminal.state").terminals[slot]
    if not term then return end
    local win = vim.api.nvim_get_current_win()
    term:toggle()
    vim.api.nvim_set_current_win(win)
end

---Toggle all terminals. Close all if any are open, open all if all are closed.
function M.toggle_all()
    local state = require("code-runner.terminal.state")
    local any_open = state.open_count() > 0

    local win = vim.api.nvim_get_current_win()
    for _, term in pairs(state.terminals) do
        if any_open then
            if term:is_open() then term:close() end
        else
            term:open()
        end
    end
    vim.api.nvim_set_current_win(win)
end

---Close the given terminal
---@param slot integer?
function M.close(slot)
    slot = slot or terminal_slot_input()
    if not slot then return end
    local term = require("code-runner.terminal.state").terminals[slot]
    if term then require("code-runner.terminal.commands").interrupt(slot) end
end

---Close all visible runner terminals
function M.close_all()
    for slot in pairs(require("code-runner.terminal.state").terminals) do
        require("code-runner.terminal.commands").interrupt(slot)
    end
end

return M
