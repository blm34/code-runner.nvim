local M = {}

---@module "code-runner.config"
local config = require("code-runner.config")
---@module "code-runner.utils"
local utils = require("code-runner.utils")

---@type string
local python_path_within_venv = utils.is_windows
    and vim.fs.joinpath("Scripts", "python.exe")
    or vim.fs.joinpath("bin", "python")

---@param dir string
---@return string?
local function python_in_dir(dir)
    if not dir or dir == "" then return nil end
    for _, venv_name in ipairs(config.options.runners.python.venv_names) do
        local path = vim.fs.joinpath(dir, venv_name, python_path_within_venv)
        if utils.is_executable(path) then return path end
    end
end

---@param start_dir string
---@return string?
local function find_venv_upwards(start_dir)
    local cur = vim.fn.fnamemodify(start_dir, ":p")
    local prev = ""
    while cur ~= prev do
        local py = python_in_dir(cur)
        if py then return py end
        prev = cur
        cur = vim.fn.fnamemodify(cur, ":h")
    end
end

---@return string?
local function get_python_executable()
    local venv = os.getenv("VIRTUAL_ENV")
    if venv and venv ~= "" then
        local path = vim.fs.joinpath(venv, python_path_within_venv)
        if utils.is_executable(path) then return path end
    end

    local buf = vim.api.nvim_buf_get_name(0)
    local dir = buf ~= "" and vim.fn.fnamemodify(buf, ":h") or vim.fn.getcwd()
    local found = find_venv_upwards(dir)
    if found then return found end
    if vim.fn.executable("python3") == 1 then return "python3" end
    if vim.fn.executable("python") == 1 then return "python" end
end

---@param path string
---@return string?
function M.build_command(path)
    local py = get_python_executable()
    if not py then
        vim.notify("[CodeRunner] No Python interpreter found", vim.log.levels.ERROR)
        return nil
    end
    return string.format("%s %s", utils.escape_arg(py), utils.escape_arg(path))
end

---@type string[]
M.filetypes = { "python" }

return M
