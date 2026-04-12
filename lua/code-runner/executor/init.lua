local M = {}

---Get the path of the current file
---@return string?
local function get_current_file_path()
    local path = vim.fn.expand("%:p")
    if path == "" or vim.fn.filereadable(path) == 0 then
        vim.notify("[CodeRunner] No readable file", vim.log.levels.WARN)
        return nil
    end
    return path
end

---Run the currently focused file
local function _run_current_file()
    local path = get_current_file_path()
    if not path then return end
    require("code-runner.executor.core").run_file(path)
end

---Run the currently focused file in a new teminal
local function _run_current_file_in_new_terminal()
    local path = get_current_file_path()
    if not path then return end
    require("code-runner.executor.core").run_file_in_new_terminal(path)
end

---Run the current focused file
---@param new_terminal boolean
function M.run_current_file(new_terminal)
    if new_terminal then
        _run_current_file_in_new_terminal()
    else
        _run_current_file()
    end
end

---Pick a register (or use given register) and run the file in it
---@param register string?
local function _run_file_from_register(register)
    local core = require("code-runner.executor.core")
    local registers = require("code-runner.executor.registers")
    if register then
        local path = registers.get_path_from_register(register)
        if path then core.run_file(path) end
        return
    end

    local supported_filetypes = core.get_supported_filetypes()
    local registers_list = registers.get_registers_containing_filepaths(supported_filetypes)
    registers.select_register_and_run(registers_list, core.run_file)
end

---Pick a register (or use given register) and run the file in it in a new terminal
---@param register string?
local function _run_file_from_register_in_new_terminal(register)
    local core = require("code-runner.executor.core")
    local registers = require("code-runner.executor.registers")
    if register then
        local path = registers.get_path_from_register(register)
        if path then core.run_file_in_new_terminal(path) end
        return
    end

    local supported_filetypes = core.get_supported_filetypes()
    local registers_list = registers.get_registers_containing_filepaths(supported_filetypes)
    registers.select_register_and_run(registers_list, core.run_file_in_new_terminal)
end

---Run a file from filepath stored in a register
---@param opts {register: string?, new_terminal: boolean?}?
function M.run_file_from_register(opts)
    opts = opts or {}
    local new_terminal = opts.new_terminal or false
    if new_terminal then
        _run_file_from_register_in_new_terminal(opts.register)
    else
        _run_file_from_register(opts.register)
    end
end

---Save the current open filepath to a register
---@param register string?
function M.save_current_file_path_to_register(register)
    local path = get_current_file_path()
    if not path then return end

    register = register or vim.fn.input("Save to register (a-z): ")
    if not register or register == "" then return end

    if not register:match("^[a-z]$") then
        vim.notify("[CodeRunner] Register must be a single letter a-z", vim.log.levels.WARN)
        return
    end

    vim.fn.setreg(register, path)
    vim.notify("[CodeRunner] Saved " .. path .. " into @" .. register)
end

---Rerun the last run command
local function _rerun_last()
    require("code-runner.executor.core").rerun_last()
end

---Rerun the last run command in a new terminal
local function _rerun_last_in_new_terminal()
    require("code-runner.executor.core").rerun_last_in_new_terminal()
end

---Rerun the last run command
---@param new_terminal boolean
function M.rerun_last(new_terminal)
    if new_terminal then
        _rerun_last_in_new_terminal()
    else
        _rerun_last()
    end
end

return M
