local M = {}

---@class CodeRunnerPythonConfig
---@field venv_names string[]

---@class CodeRunnerRunnersConfig
---@field python CodeRunnerPythonConfig

---@class BusyBehaviour
---@field behaviour "ask" | "interrupt" | "cancel" | "new"
---@field interrupt_delay_ms integer

---@class CodeRunnerConfig
---@field max_slots integer Maximum 9
---@field slot_id_offset integer
---@field busy_behaviour BusyBehaviour
---@field runners CodeRunnerRunnersConfig

---@type CodeRunnerConfig
M.defaults = {
    max_slots = 3,
    slot_id_offset = 100,
    -- Unnest this part
    busy_behaviour = {
        behaviour = "ask",
        interrupt_delay_ms = 100,
    },
    runners = {
        python = {
            venv_names = { ".venv", "venv", ".env", "env" },
        },
    },
}

---@type CodeRunnerConfig
M.options = M.defaults

---@class CodeRunnerPythonConfigOpts
---@field venv_names string[]?

---@class CodeRunnerRunnersConfigOpts
---@field python CodeRunnerPythonConfig?

---@class BusyBehaviourOpts
---@field behaviour "ask" | "interrupt" | "cancel" | "new"?
---@field interrupt_delay_ms integer?

---@class CodeRunnerConfigOpts
---@field max_slots integer? Maximum 9
---@field slot_id_offset integer?
---@field busy_behaviour BusyBehaviour?
---@field runners CodeRunnerRunnersConfig?

---@param opts CodeRunnerConfigOpts?
function M.setup(opts)
    opts = opts or {}
    M.options = vim.tbl_deep_extend("force", M.defaults, opts)

    if M.options.max_slots > 9 then
        vim.notify("[CodeRunner] Maximum number of slots cannot be more than 9, setting to 9", vim.log.levels.WARN)
        M.options.max_slots = 9
    end
end

return M
