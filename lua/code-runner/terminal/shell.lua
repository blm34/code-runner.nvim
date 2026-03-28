local M     = {}

---@module "code-runner.utils"
local utils = require("code-runner.utils")

---Get the command seperator for the current terminal
---@return string
function M.command_seperator()
    if not utils.is_windows then return " ; " end
    if utils.is_pwsh() then
        return " ; "
    end
    return " & "
end

---Generate the command that creates a sentinel file
---@param sentinel string
---@return string
function M.touch_command(sentinel)
    if not utils.is_windows then return "touch " .. sentinel end
    if utils.is_pwsh() then
        return "New-Item -ItemType File -Force '" .. sentinel .. "' | Out-Null"
    end
    return "type nul > " .. sentinel
end

---Generate a command to run echo cross platform
---@param msg string
---@return string
function M.echo_command(msg)
    if not utils.is_windows then return "echo '" .. msg .. "'" end
    if utils.is_pwsh() then return "Write-Host '" .. msg .. "'" end
    return "echo " .. msg
end

return M
