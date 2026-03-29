local M = {}

---@module "code-runner.config"
local config = require("code-runner.config")
---@module "code-runner.executor"
local executor = require("code-runner.executor")
---@module "code-runner.terminal"
local terminal = require("code-runner.terminal")

---Setup up the plugin.
---@param opts CodeRunnerConfig?
function M.setup(opts)
    config.setup(opts)
end

---------- FUNCTIONS TO RUN FILES ----------

---Run the currently focused file.
---@param new_terminal boolean?
function M.run_current_file(new_terminal)
    executor.run_current_file(new_terminal or false)
end

---Run a file from a filepath stored in a register.
---@param opts {register: string?, new_terminal: boolean?}
function M.run_file_from_register(opts)
    executor.run_file_from_register(opts)
end

---Rerun the last run command.
---@param new_terminal boolean?
function M.rerun_last_command(new_terminal)
    new_terminal = new_terminal or false
    executor.rerun_last(new_terminal)
end

---------- FUNCTIONS TO SAVE COMMANDS/PARAMETERS ----------

---Save the filepath of the currently focused file in a register. UI to select a register of not passed.
---@param register string?
function M.save_current_file_path_to_register(register)
    executor.save_current_file_path_to_register(register)
end

---------- FUNCTIONS TO MANAGE TERMINALS ----------

---Toggle a terminal's visibility. If no slot specified, the user will be asked for one.
---@param slot integer?
function M.toggle_terminal(slot)
    terminal.toggle(slot)
end

---Toggle the visibility of all terminals. Close all if any open. If all closed then open all.
function M.toggle_all_terminals()
    terminal.toggle_all()
end

---Interrupt and shutdown a terminal.
---@param slot integer?
function M.close_terminal(slot)
    terminal.close(slot)
end

---Interrupt and shutdown all terminals.
function M.close_all_terminals()
    terminal.close_all()
end

return M
