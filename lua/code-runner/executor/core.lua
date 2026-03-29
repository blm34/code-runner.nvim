local M = {}

---@module "code-runner.terminal"
local terminal = require("code-runner.terminal")

---@type string?
local last_run_path = nil

---@class CodeRunnerImplementation
---@field build_command fun(path: string): string?
---@field filetypes string[]

---@type table<string, CodeRunnerImplementation>
local runners = {
    ---@module "code-runner.languages.python"
    python = require("code-runner.languages.python")
}

---Get the filetype of the given file
---@param path string
---@return string?
local function get_filetype(path)
    local filetype = vim.filetype.match({ filename = path })
    if not filetype then
        vim.notify("[CodeRunner] Could not detect filetype for: " .. path, vim.log.levels.WARN)
        return nil
    end
    return filetype
end

---Get the runner for the given filetype
---@param filetype string
---@return CodeRunnerImplementation?
local function get_runner_for_filetype(filetype)
    local r = runners[filetype]
    if not r then
        vim.notify("[CodeRunner] No runner for filetype: " .. filetype, vim.log.levels.WARN)
    end
    return r
end

---Get a table of supported filetypes
---@return table<string, boolean>
function M.get_supported_filetypes()
    ---@type table<string, boolean>
    local supported_filetypes = {}
    for _, runner in pairs(runners) do
        for _, filetype in ipairs(runner.filetypes) do
            supported_filetypes[filetype] = true
        end
    end
    return supported_filetypes
end

---Generate a command to run the given file
---@param path string
---@return string?
local function get_command_to_run_file(path)
    local filetype = get_filetype(path)
    if not filetype then return end

    local runner = get_runner_for_filetype(filetype)
    if not runner then return end

    local cmd = runner.build_command(path)
    if not cmd then return end

    return cmd
end

---Run the file at the given path
---@param path string
function M.run_file(path)
    local cmd = get_command_to_run_file(path)
    if cmd then
        last_run_path = path
        terminal.run(cmd)
    end
end

---Run the file at the given path in new terminal
---@param path string
function M.run_file_in_new_terminal(path)
    local cmd = get_command_to_run_file(path)
    if cmd then
        last_run_path = path
        terminal.run_in_new_terminal(cmd)
    end
end

---Rerun the last run file
function M.rerun_last()
    if not last_run_path then
        vim.notify("[CodeRunner] No file has been run yet", vim.log.levels.WARN)
        return
    end
    M.run_file(last_run_path)
end

---Rerun the last run file in a new terminal
function M.rerun_last_in_new_terminal()
    if not last_run_path then
        vim.notify("[CodeRunner] No file has been run yet", vim.log.levels.WARN)
        return
    end
    M.run_file_in_new_terminal(last_run_path)
end

return M
