-- A minimal stub of the `vim` global that satisfies every module in
-- code-runner.nvim. Individual specs can averride specific fields after
-- calling `setup()` to tailor behaviour for a particular test.

local M = {}

-- Modules that must be evicted from package.loaded between tests
-- so that re-requiring them picks up the latest vim mock.
local PLUGIN_MODULES = {
    "code-runner",
    "code-runner.config",
    "code-runner.executor.registers",
    "code-runner.executor.core",
    "code-runner.executor",
    "code-runner.languages.python",
    "code-runner.terminal.shell",
    "code-runner.terminal.state",
    "code-runner.terminal.commands",
    "code-runner.terminal",
    "code-runner.utils",
}

---Returns true if a table is list-like (sequential integer keys from 1).
---@param t table
---@return boolean
local function is_list(t)
    if type(t) ~= "table" then return false end
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end

--- Standalone recursive deep-merge used by the mock's vim.tbl_deep_extend.
---@param _mode  string   ignored (mirrors the real API)
---@param base   table
---@param override table?
---@return table
local function deep_extend(_mode, base, override)
    local result = {}
    for k, v in pairs(base) do result[k] = v end
    if override then
        for k, v in pairs(override) do
            if type(v) == "table" and type(result[k]) == "table" and not is_list(v) and not is_list(result[k]) then
                result[k] = deep_extend(_mode, result[k], v)
            else
                result[k] = v
            end
        end
    end
    return result
end

---Build and install a fresh vim mock into _G.vim, returning it.
---@return table
function M.setup()
    -- A minimal spy/stub factory
    local function spy_fn(ret)
        return function(...) return ret end
    end

    local mock = {
        log = {
            levels = { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3 },
        },
        fn = {
            has = function(_) return 0 end,
            expand = function(expr) return expr end,
            fnamemodify = function(path, _) return path end,
            filereadable = function(_) return 1 end,
            executable = function(_) return 1 end,
            getcwd = spy_fn("/tmp"),
            stdpath = function(_) return "/tmp" end,
            getreg = spy_fn(""),
            setreg = function(_, _) end,
            delete = function(_) end,
            writefile = function(...) end,
            input = spy_fn(""),
            getcharstr = spy_fn("1"),
        },
        fs = {
            joinpath = function(...)
                local parts = { ... }
                return table.concat(parts, "/")
            end,
        },
        uv = {
            fs_stat = function(_) return nil end,
        },
        filetype = {
            match = function(opts)
                if opts and opts.filename then
                    if opts.filename:match("%.py$") then return "python" end
                    if opts.filename:match("%.lua$") then return "lua" end
                end
                return nil
            end,
        },
        api = {
            nvim_buf_get_name = spy_fn("/tmp/test_file.py"),
            nvim_get_current_win = spy_fn(1),
            nvim_win_is_valid = spy_fn(true),
            nvim_set_current_win = function(_) end,
            nvim_echo = function(...) end,
        },
        ui = {
            select = function(items, _, callback) callback(items[1]) end,
        },
        o = {
            shell = "/bin/bash",
        },
        notify = function(...) end,
        schedule = function(fn) fn() end,
        defer_fn = function(fn, _) fn() end,
        tbl_deep_extend = deep_extend
    }

    _G.vim = mock
    return mock
end

---Return the current vim mock (must call setup() first).
---@return table
function M.get()
    return _G.vim
end

---Wipe all plugin modules from package.loaded so the next require() runs
---the module fresh against the current vim mock.
function M.teardown()
    for _, mod in ipairs(PLUGIN_MODULES) do
        package.loaded[mod] = nil
    end
end

return M
