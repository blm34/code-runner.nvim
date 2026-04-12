local M      = {}

---@module "code-runner.config"
local config = require("code-runner.config")
---@module "code-runner.utils"
local utils  = require("code-runner.utils")
---@module "code-runner.terminal.state"
local state  = require("code-runner.terminal.state")
---@module "code-runner.terminal.shell"
local shell  = require("code-runner.terminal.shell")

---Send a command to the given terminal.
---@param slot integer
---@param cmd string
function M.send(slot, cmd)
    local term = state.terminals[slot] or state.create_terminal(slot)
    if not term then return end

    local sentinel = state.sentinel_path(slot)
    vim.fn.delete(sentinel)

    local clear_cmd = utils.is_windows and "cls" or "clear"
    local full_cmd = clear_cmd
        .. shell.command_seperator()
        .. shell.echo_command(">>> " .. cmd)
        .. shell.command_seperator()
        .. cmd
        .. shell.command_seperator()
        .. shell.touch_command(sentinel)

    local win = vim.api.nvim_get_current_win()
    if not term:is_open() then term:open() end
    term:send(full_cmd, true)
    vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_set_current_win(win)
        end
    end)
end

---Interrupt and close a terminal
---@param slot integer
function M.interrupt(slot)
    local term = state.terminals[slot]
    if not term then return end

    term:shutdown()

    state.terminals[slot] = nil
    vim.fn.writefile({}, state.sentinel_path(slot))
end

---Interrupt a terminal and send it a new command.
---@param slot integer
---@param cmd string
function M.interrupt_and_run(slot, cmd)
    M.interrupt(slot)
    vim.defer_fn(
        function()
            M.send(slot, cmd)
        end,
        config.options.busy_behaviour.interrupt_delay_ms
    )
end

---Interrupt a terminal and send a command, or cancel the command
---@param slot integer
---@param cmd string
---@param behaviour "interrupt" | "cancel"
function M.apply_busy_behaviour(slot, cmd, behaviour)
    if behaviour == "cancel" then
        return
    elseif behaviour == "interrupt" then
        M.interrupt_and_run(slot, cmd)
    end
end

---Determine the correct behaviour for running a command in a busy terminal
---@param slot integer
---@param cmd string
function M.resolve_busy_behaviour(slot, cmd)
    local behaviour = config.options.busy_behaviour.interrupt_delay_ms

    if behaviour ~= "ask" then
        ---@diagnostic disable-next-line: param-type-mismatch
        M.apply_busy_behaviour(slot, cmd, behaviour)
        return
    end

    vim.ui.select(
        { "Cancel", "Interrupt" },
        { prompt = "Terminal " .. slot .. " is busy:" },
        function(choice)
            if choice then
                M.apply_busy_behaviour(slot, cmd, string.lower(choice))
            end
        end
    )
end

---Run a command in a brand new terminal slot
---@param cmd string
function M.run_in_new_slot(cmd)
    local slot = state.next_slot()
    M.send(slot, cmd)
end

return M
