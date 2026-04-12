--- A shared stub for the toggleterm.terminal module.

local M = {}

---@class FakeTerminal
---@field _opts          table    Options passed to :new()
---@field _is_open       boolean  Current visibility state
---@field _open_count    integer  Number of times open()     was called
---@field _close_count   integer  Number of times close()    was called
---@field _toggle_count  integer  Number of times toggle()   was called
---@field _shutdown_calls integer Number of times shutdown() was called
---@field _send_args     {cmd:string, nl:boolean?}[]  Arguments from each send() call

local Terminal = {}
Terminal.__index = Terminal

---Create a new fake Terminal instance.
---@param opts {is_open: boolean?}?
---@return FakeTerminal
function Terminal:new(opts)
    opts              = opts or {}
    local t           = setmetatable({}, self)
    t._opts           = opts
    t._is_open        = opts.is_open or false
    t._open_count     = 0
    t._close_count    = 0
    t._toggle_count   = 0
    t._shutdown_calls = 0
    t._send_args      = {}
    return t
end

function Terminal:is_open()
    return self._is_open
end

function Terminal:open()
    self._is_open = true
    self._open_count = self._open_count + 1
end

function Terminal:close()
    self._is_open = false
    self._close_count = self._close_count + 1
end

function Terminal:toggle()
    self._is_open = not self._is_open
    self._toggle_count = self._toggle_count + 1
end

---Send a command to the terminal
---@param cmd string
---@param nl  boolean?
function Terminal:send(cmd, nl)
    table.insert(self._send_args, { cmd = cmd, nl = nl })
end

---Shutdown the terminal
function Terminal:shutdown()
    self._is_open = false
    self._shutdown_calls = self._shutdown_calls + 1
end

M.Terminal = Terminal

---Build a standalone Terminal instance without going through the class.
---Shorthand for `Terminal:new({ is_open = is_open })`.
---@param is_open boolean  Initial visibility state.
---@return FakeTerminal
function M.make_terminal(is_open)
    return Terminal:new({ is_open = is_open })
end

---Install the fake into package.loaded so that
function M.setup()
    package.loaded["toggleterm.terminal"] = { Terminal = Terminal }
end

---Remove the fake from package.loaded.
function M.teardown()
    package.loaded["toggleterm.terminal"] = nil
end

return M
