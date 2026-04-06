--- state.lua depends on toggleterm.terminal, which is not available in a
--- plain Lua test environment.  We stub it out via package.loaded before
--- the module is first required.

local vim_mock = require("helpers.vim_mock")
local toggleterm_mock = require("helpers.toggleterm_mock")

describe("code-runner.terminal.state", function()
    local state

    before_each(function()
        vim_mock.setup()
        toggleterm_mock.setup()
        package.loaded["code-runner.terminal.state"] = nil
        package.loaded["code-runner.config"]         = nil

        local config                                 = require("code-runner.config")
        config.setup({ max_slots = 3, slot_id_offset = 100 })
        state           = require("code-runner.terminal.state")
        state.terminals = {}
    end)

    after_each(function()
        vim_mock.teardown()
        toggleterm_mock.teardown()
        package.loaded["code-runner.terminal.state"] = nil
    end)

    describe("sentinel_path()", function()
        it("returns a non-empty string", function()
            local p = state.sentinel_path(1)
            assert.is_string(p)
            assert.is_truthy(#p > 0)
        end)

        it("encodes the slot number in the path", function()
            local p1 = state.sentinel_path(1)
            local p2 = state.sentinel_path(2)
            -- Paths for different slots must differ
            assert.is_not.equal(p1, p2)
        end)

        it("is stable — same slot always returns the same path", function()
            assert.equal(state.sentinel_path(3), state.sentinel_path(3))
        end)
    end)

    describe("next_slot()", function()
        it("returns 1 when no terminals exist", function()
            assert.equal(1, state.next_slot())
        end)

        it("returns 2 when slot 1 is occupied", function()
            state.terminals[1] = {}
            assert.equal(2, state.next_slot())
        end)

        it("fills gaps — returns 2 when only slots 1 and 3 are occupied", function()
            state.terminals[1] = {}
            state.terminals[3] = {}
            assert.equal(2, state.next_slot())
        end)
    end)

    describe("create_terminal()", function()
        it("creates and returns a terminal object in the given slot", function()
            local t = state.create_terminal(1)
            assert.is_not_nil(t)
            assert.is_not_nil(state.terminals[1])
        end)

        it("returns nil and warns when max_slots is exceeded", function()
            local warned = false
            vim_mock.get().notify = function(_, level)
                if level == vim_mock.get().log.levels.WARN then warned = true end
            end
            -- config.max_slots = 3; try to create slot 4
            local t = state.create_terminal(4)
            assert.is_nil(t)
            assert.is_true(warned)
        end)

        it("writes the initial sentinel file", function()
            local written = {}
            vim_mock.get().fn.writefile = function(_, p) table.insert(written, p) end
            state.create_terminal(1)
            assert.equal(1, #written)
        end)
    end)

    describe("is_busy()", function()
        it("returns false when no terminal exists in that slot", function()
            assert.is_false(state.is_busy(1))
        end)

        it("returns false when terminal exists and sentinel file is readable (idle)", function()
            state.terminals[1] = {}
            vim_mock.get().fn.filereadable = function(_) return 1 end
            assert.is_false(state.is_busy(1))
        end)

        it("returns true when terminal exists and sentinel file is NOT readable (busy)", function()
            state.terminals[1] = {}
            vim_mock.get().fn.filereadable = function(_) return 0 end
            assert.is_true(state.is_busy(1))
        end)
    end)

    describe("first_idle_slot()", function()
        it("returns nil when no terminals exist", function()
            assert.is_nil(state.first_idle_slot())
        end)

        it("returns the slot when that terminal is idle", function()
            state.terminals[5] = {}
            vim_mock.get().fn.filereadable = function(_) return 1 end
            assert.equal(5, state.first_idle_slot())
        end)

        it("returns nil when all terminals are busy", function()
            state.terminals[1] = {}
            state.terminals[2] = {}
            vim_mock.get().fn.filereadable = function(_) return 0 end
            assert.is_nil(state.first_idle_slot())
        end)

        it("returns 2 if 1 is busy", function()
            vim_mock.get().fn.filereadable = function(file)
                if file:match("code%-runner%-slot%-1%.free$") then
                    return 0
                else
                    return 1
                end
            end
            package.loaded["code-runner.terminal.state"] = nil
            state = require("code-runner.terminal.state")

            state.terminals[1] = {}
            state.terminals[2] = {}

            assert.equal(2, state.first_idle_slot())
        end)
    end)

    describe("terminal_count()", function()
        it("returns 0 when no terminals exist", function()
            assert.equal(0, state.terminal_count())
        end)

        it("returns the correct count", function()
            state.terminals[1] = {}
            state.terminals[2] = {}
            assert.equal(2, state.terminal_count())
        end)
    end)

    describe("open_count()", function()
        it("returns 0 when no terminals exist", function()
            assert.equal(0, state.open_count())
        end)

        it("counts only open terminals", function()
            local open_term    = toggleterm_mock.make_terminal(true)
            local closed_term  = toggleterm_mock.make_terminal(false)
            open_term._is_open = true
            state.terminals[1] = open_term
            state.terminals[2] = closed_term
            assert.equal(1, state.open_count())
        end)
    end)

    describe("first_slot()", function()
        it("returns nil when no terminals exist", function()
            assert.is_nil(state.first_slot())
        end)

        it("returns the lowest-numbered slot", function()
            state.terminals[3] = {}
            state.terminals[1] = {}
            state.terminals[2] = {}
            assert.equal(1, state.first_slot())
        end)
    end)
end)
