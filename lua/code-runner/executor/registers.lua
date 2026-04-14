local M = {}

---@class RegisterEntry
---@field reg string
---@field path string
---@field label string

---Get a filepath from a register
---@param reg string
---@return string?
function M.get_path_from_register(reg)
    local path = vim.fn.getreg(reg):gsub("%s+$", "")
    if path == "" then
        vim.notify("[CodeRunner] Register @" .. reg .. " is empty", vim.log.levels.WARN)
        return nil
    end

    if vim.fn.filereadable(path) == 0 then
        vim.notify("[CodeRunner] File not found: " .. path, vim.log.levels.ERROR)
        return nil
    end

    return path
end

---Generate a list of registers containing paths to files of the given filetypes
---@param supported_filetypes table<string, boolean>
---@return RegisterEntry[]
function M.get_registers_containing_filepaths(supported_filetypes)
    ---@type RegisterEntry[]
    local regs = {}
    for i = string.byte("a"), string.byte("z") do
        local reg = string.char(i)
        local contents = vim.fn.getreg(reg)
        if contents and contents ~= "" then
            local path = contents:gsub("\n", ""):gsub("%s+$", "")
            if vim.fn.filereadable(path) ~= 0 then
                local filetype = vim.filetype.match({ filename = path })
                if filetype and supported_filetypes[filetype] then
                    table.insert(
                        regs,
                        {
                            reg = reg,
                            path = path,
                            label = string.format("@%s: %s", reg, path)
                        }
                    )
                end
            end
        end
    end
    return regs
end

---Run the file in a register selected by the user
---@param registers RegisterEntry[]
---@param runner_func fun(path: string)
function M.select_register_and_run(registers, runner_func)
    if #registers == 0 then
        vim.notify("[CodeRunner] No registers contain runnable filepaths", vim.log.levels.WARN)
        return
    end

    table.sort(registers, function(a, b) return a.reg < b.reg end)
    vim.ui.select(
        registers,
        {
            prompt = "Select register to run:",
            ---@param item RegisterEntry
            format_item = function(item) return item.label end,
        },
        function(choice)
            if not choice then return end
            runner_func(choice.path)
        end
    )
end

return M
