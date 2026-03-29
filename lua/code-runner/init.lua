local M = {}

-- TODO: Does this need tests?

---Setup up the plugin.
---@param opts CodeRunnerConfigOpts?
function M.setup(opts)
    require("code-runner.config").setup(opts)
end

---------- FUNCTIONS TO RUN FILES ----------

---Run the currently focused file.
---@param new_terminal boolean?
function M.run_current_file(new_terminal)
    require("code-runner.executor").run_current_file(new_terminal or false)
end

---Run a file from a filepath stored in a register.
---@param opts {register: string?, new_terminal: boolean?}
function M.run_file_from_register(opts)
    require("code-runner.executor").run_file_from_register(opts)
end

---Rerun the last run command.
---@param new_terminal boolean?
function M.rerun_last_command(new_terminal)
    new_terminal = new_terminal or false
    require("code-runner.executor").rerun_last(new_terminal)
end

---------- FUNCTIONS TO SAVE COMMANDS/PARAMETERS ----------

---Save the filepath of the currently focused file in a register. UI to select a register of not passed.
---@param register string?
function M.save_current_file_path_to_register(register)
    require("code-runner.executor").save_current_file_path_to_register(register)
end

---------- FUNCTIONS TO MANAGE TERMINALS ----------

---Toggle a terminal's visibility. If no slot specified, the user will be asked for one.
---@param slot integer?
function M.toggle_terminal(slot)
    require("code-runner.terminal").toggle(slot)
end

---Toggle the visibility of all terminals. Close all if any open. If all closed then open all.
function M.toggle_all_terminals()
    require("code-runner.terminal").toggle_all()
end

---Interrupt and shutdown a terminal.
---@param slot integer?
function M.close_terminal(slot)
    require("code-runner.terminal").close(slot)
end

---Interrupt and shutdown all terminals.
function M.close_all_terminals()
    require("code-runner.terminal").close_all()
end

return M
