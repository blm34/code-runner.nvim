local M = {}

---Is the operating system windows?
---@type boolean
M.is_windows = vim.fn.has("win32") == 1

---Is the terminal powershell?
---@type boolean
M.is_pwsh = vim.o.shell:lower():match("powershell") ~= nil
    or vim.o.shell:lower():match("pwsh") ~= nil

---Is the given file executable
---@param path string
---@return boolean
function M.is_executable(path)
    if not path or path == "" then return false end
    return vim.uv.fs_stat(path) ~= nil
end

---Wrap the given argument in quotes
---@param arg string
---@return string
function M.escape_arg(arg)
    if M.is_windows then
        if M.is_pwsh then
            -- Powershell
            if arg == "" then return "''" end
            if arg:match("[%s'`\"$&|<>@#%(%){}]") then
                local escaped = arg
                    :gsub("'", "''")
                    :gsub("`", "``")
                    :gsub("%$", "`$")
                    :gsub('"', '`"')
                return "'" .. escaped .. "'"
            end
            return arg
        else
            -- CMD
            if arg == "" then return '""' end
            if arg:match('[%s"&|<>^]') then
                local escaped = arg
                    :gsub('"', '""')
                    :gsub('[&|<>^]', '^%0')
                return '"' .. escaped .. '"'
            end
            return arg
        end
    else
        -- Unix
        if arg == "" then return "''" end
        if arg:match("[^%w%-%_%.%/]") then
            local escaped = arg:gsub("'", "'\\''")
            return "'" .. escaped .. "'"
        end
        return arg
    end
end

return M
