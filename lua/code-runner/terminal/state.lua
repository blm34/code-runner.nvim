local M        = {}

---@module "toggleterm.terminal"
local Terminal = require("toggleterm.terminal").Terminal
---@module "code-runner.config"
local config   = require("code-runner.config")

---@type table<integer, table>
M.terminals    = {}

---Return a sentinel file path to signify a running terminal
---@param slot integer
---@return string
function M.sentinel_path(slot)
    return vim.fs.joinpath(
        vim.fn.stdpath("cache"), "code-runner-slot-" .. slot .. ".free"
    )
end

---Is a given terminal currently running some code
---@param slot integer
---@return boolean
function M.is_busy(slot)
    return M.terminals[slot] ~= nil and vim.fn.filereadable(M.sentinel_path(slot)) == 0
end

---Get the next available slot, filling gaps left by destroyed terminals
---@return integer
function M.next_slot()
    local slot = 1
    while M.terminals[slot] do
        slot = slot + 1
    end
    return slot
end

---Create a terminal in the given slot
---@param slot integer
---@return table?
function M.create_terminal(slot)
    if slot > config.options.max_slots then
        vim.notify("[CodeRunner] Maximum number of slots reached (" .. config.options.max_slots .. ")",
            vim.log.levels.WARN)
        return
    end

    M.terminals[slot] = Terminal:new({
        id = config.options.slot_id_offset + slot,
        display_name = "Code Runner " .. slot,
        direction = "horizontal",
        close_on_exit = false,
        hidden = false,
    })
    vim.fn.writefile({}, M.sentinel_path(slot))
    return M.terminals[slot]
end

---Get the first slot by lowest number
---@return integer?
function M.first_slot()
    local first = nil
    for slot in pairs(M.terminals) do
        if not first or slot < first then
            first = slot
        end
    end
    return first
end

---Get the first idle terminal slot, or nil if all are busy
---@return integer?
function M.first_idle_slot()
    for slot in pairs(M.terminals) do
        if not M.is_busy(slot) then return slot end
    end
    return nil
end

---Count how many terminals exist
---@return integer
function M.terminal_count()
    local count = 0
    for _ in pairs(M.terminals) do count = count + 1 end
    return count
end

---Count how many terminals are currently open (visible)
---@return integer
function M.open_count()
    local count = 0
    for _, term in pairs(M.terminals) do
        if term:is_open() then count = count + 1 end
    end
    return count
end

return M
