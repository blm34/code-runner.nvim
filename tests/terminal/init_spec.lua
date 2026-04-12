local vim_mock        = require("helpers.vim_mock")
local toggleterm_mock = require("helpers.toggleterm_mock")

-- ---------------------------------------------------------------------------
-- Fakes
-- ---------------------------------------------------------------------------

local function install_fake_commands()
    local fake = {
        send_calls              = {},
        interrupt_calls         = {},
        interrupt_and_run_calls = {},
        run_in_new_slot_calls   = {},
    }
    function fake.send(slot, cmd)
        table.insert(fake.send_calls, { slot = slot, cmd = cmd })
    end

    function fake.interrupt(slot)
        table.insert(fake.interrupt_calls, slot)
    end

    function fake.interrupt_and_run(slot, cmd)
        table.insert(fake.interrupt_and_run_calls, { slot = slot, cmd = cmd })
    end

    function fake.run_in_new_slot(cmd)
        table.insert(fake.run_in_new_slot_calls, cmd)
    end

    package.loaded["code-runner.terminal.commands"] = fake
    return fake
end

local function install_fake_state(overrides)
    local fake = {
        terminals   = {},
        _count      = 0,
        _idle_slot  = nil,
        _first_slot = nil,
        _open_count = 0,
    }
    function fake.terminal_count() return fake._count end

    function fake.next_slot() return fake._count + 1 end

    function fake.first_idle_slot() return fake._idle_slot end

    function fake.first_slot() return fake._first_slot end

    function fake.open_count() return fake._open_count end

    if overrides then
        for k, v in pairs(overrides) do fake[k] = v end
    end

    package.loaded["code-runner.terminal.state"] = fake
    return fake
end

local function install_fake_config(busy_behaviour)
    local fake = { options = { busy_behaviour = busy_behaviour or "ask" } }
    package.loaded["code-runner.config"] = fake
    return fake
end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

describe("code-runner.terminal", function()
    local terminal
    local fake_commands
    local fake_state
    local fake_config

    before_each(function()
        vim_mock.setup()

        fake_commands                          = install_fake_commands()
        fake_state                             = install_fake_state()
        fake_config                            = install_fake_config()

        package.loaded["code-runner.terminal"] = nil
        terminal                               = require("code-runner.terminal")
    end)

    after_each(function()
        package.loaded["code-runner.terminal.commands"] = nil
        package.loaded["code-runner.terminal.state"]    = nil
        package.loaded["code-runner.config"]            = nil
        package.loaded["code-runner.terminal"]          = nil
        vim_mock.teardown()
    end)

    describe("run()", function()
        describe("when no terminals exist", function()
            it("sends the command to slot 1", function()
                fake_state._count = 0

                terminal.run("python /tmp/script.py")

                assert.equal(1, #fake_commands.send_calls)
                assert.equal(1, fake_commands.send_calls[1].slot)
                assert.equal("python /tmp/script.py", fake_commands.send_calls[1].cmd)
            end)
        end)

        describe("when an idle terminal exists", function()
            it("sends the command to the idle slot", function()
                fake_state._count     = 1
                fake_state._idle_slot = 2

                terminal.run("python /tmp/script.py")

                assert.equal(1, #fake_commands.send_calls)
                assert.equal(2, fake_commands.send_calls[1].slot)
            end)

            it("does not open a new slot", function()
                fake_state._count     = 1
                fake_state._idle_slot = 1

                terminal.run("python /tmp/script.py")

                assert.equal(0, #fake_commands.run_in_new_slot_calls)
            end)
        end)

        describe("when all terminals are busy", function()
            before_each(function()
                fake_state._count      = 2
                fake_state._idle_slot  = nil
                fake_state._first_slot = 1
            end)

            it("cancels silently for busy_behaviour = 'cancel'", function()
                fake_config.options.busy_behaviour = "cancel"

                terminal.run("python /tmp/script.py")

                assert.equal(0, #fake_commands.send_calls)
                assert.equal(0, #fake_commands.interrupt_and_run_calls)
                assert.equal(0, #fake_commands.run_in_new_slot_calls)
            end)

            it("notifies when cancelling", function()
                fake_config.options.busy_behaviour = "cancel"
                local notified = false
                vim_mock.get().notify = function() notified = true end

                terminal.run("python /tmp/script.py")

                assert.is_true(notified)
            end)

            it("interrupts the first terminal for busy_behaviour = 'interrupt'", function()
                fake_config.options.busy_behaviour = "interrupt"

                terminal.run("python /tmp/script.py")

                assert.equal(1, #fake_commands.interrupt_and_run_calls)
                assert.equal(1, fake_commands.interrupt_and_run_calls[1].slot)
                assert.equal("python /tmp/script.py", fake_commands.interrupt_and_run_calls[1].cmd)
            end)

            it("opens a new slot for busy_behaviour = 'new'", function()
                fake_config.options.busy_behaviour = "new"

                terminal.run("python /tmp/script.py")

                assert.equal(1, #fake_commands.run_in_new_slot_calls)
                assert.equal("python /tmp/script.py", fake_commands.run_in_new_slot_calls[1])
            end)

            describe("busy_behaviour = 'ask'", function()
                it("presents a vim.ui.select prompt", function()
                    local select_called = false
                    vim_mock.get().ui.select = function(_, _, _)
                        select_called = true
                    end

                    terminal.run("python /tmp/script.py")

                    assert.is_true(select_called)
                end)

                it("cancels when the user picks 'Cancel'", function()
                    vim_mock.get().ui.select = function(_, _, cb) cb("Cancel") end

                    terminal.run("python /tmp/script.py")

                    assert.equal(0, #fake_commands.interrupt_and_run_calls)
                    assert.equal(0, #fake_commands.run_in_new_slot_calls)
                end)

                it("cancels when the user dismisses the prompt (nil)", function()
                    vim_mock.get().ui.select = function(_, _, cb) cb(nil) end

                    terminal.run("python /tmp/script.py")

                    assert.equal(0, #fake_commands.interrupt_and_run_calls)
                    assert.equal(0, #fake_commands.run_in_new_slot_calls)
                end)

                it("interrupts when the user picks 'Interrupt terminal'", function()
                    vim_mock.get().ui.select = function(_, _, cb) cb("Interrupt terminal") end

                    terminal.run("python /tmp/script.py")

                    assert.equal(1, #fake_commands.interrupt_and_run_calls)
                    assert.equal(1, fake_commands.interrupt_and_run_calls[1].slot)
                end)

                it("opens a new slot when the user picks 'Open new terminal'", function()
                    vim_mock.get().ui.select = function(_, _, cb) cb("Open new terminal") end

                    terminal.run("python /tmp/script.py")

                    assert.equal(1, #fake_commands.run_in_new_slot_calls)
                end)
            end)
        end)
    end)

    describe("run_in_new_terminal()", function()
        it("calls commands.run_in_new_slot with the command", function()
            terminal.run_in_new_terminal("python /tmp/script.py")
            assert.same({ "python /tmp/script.py" }, fake_commands.run_in_new_slot_calls)
        end)

        it("does not call commands.send", function()
            terminal.run_in_new_terminal("python /tmp/script.py")
            assert.equal(0, #fake_commands.send_calls)
        end)
    end)

    describe("toggle()", function()
        it("calls toggle on the terminal in the given slot", function()
            local term = toggleterm_mock.make_terminal(false)
            fake_state.terminals[2] = term

            terminal.toggle(2)

            assert.equal(1, term._toggle_count)
        end)

        it("does nothing when the slot has no terminal", function()
            -- should not error
            assert.has_no.error(function() terminal.toggle(9) end)
        end)

        it("preserves the current window", function()
            local term                              = toggleterm_mock.make_terminal(false)
            fake_state.terminals[1]                 = term
            local restored_win
            vim_mock.get().api.nvim_get_current_win = function() return 42 end
            vim_mock.get().api.nvim_set_current_win = function(w) restored_win = w end

            terminal.toggle(1)

            assert.equal(42, restored_win)
        end)

        it("prompts for a slot when none is given", function()
            local prompted               = false
            vim_mock.get().api.nvim_echo = function() prompted = true end
            vim_mock.get().fn.getcharstr = function() return "1" end
            local term                   = toggleterm_mock.make_terminal(false)
            fake_state.terminals[1]      = term

            terminal.toggle()

            assert.is_true(prompted)
            assert.equal(1, term._toggle_count)
        end)

        it("warns and does nothing for an invalid slot input", function()
            local warned = false
            vim_mock.get().fn.getcharstr = function() return "x" end
            vim_mock.get().notify = function(_, level)
                if level == vim_mock.get().log.levels.WARN then warned = true end
            end

            terminal.toggle()

            assert.is_true(warned)
        end)
    end)

    describe("toggle_all()", function()
        it("opens all terminals when all are closed", function()
            local t1 = toggleterm_mock.make_terminal(false)
            local t2 = toggleterm_mock.make_terminal(false)
            fake_state.terminals = { t1, t2 }
            fake_state._open_count = 0

            terminal.toggle_all()

            assert.equal(1, t1._open_count)
            assert.equal(1, t2._open_count)
        end)

        it("closes all open terminals when any are open", function()
            local t1 = toggleterm_mock.make_terminal(true)
            local t2 = toggleterm_mock.make_terminal(false)
            fake_state.terminals = { t1, t2 }
            fake_state._open_count = 1

            terminal.toggle_all()

            assert.equal(1, t1._close_count)
            assert.equal(0, t2._close_count) -- already closed, not touched
        end)

        it("preserves the current window", function()
            fake_state.terminals                    = {}
            fake_state._open_count                  = 0
            local restored_win
            vim_mock.get().api.nvim_get_current_win = function() return 7 end
            vim_mock.get().api.nvim_set_current_win = function(w) restored_win = w end

            terminal.toggle_all()

            assert.equal(7, restored_win)
        end)
    end)

    describe("close()", function()
        it("calls commands.interrupt for the given slot", function()
            fake_state.terminals[1] = toggleterm_mock.make_terminal(true)

            terminal.close(1)

            assert.same({ 1 }, fake_commands.interrupt_calls)
        end)

        it("does nothing when the slot has no terminal", function()
            terminal.close(9)
            assert.equal(0, #fake_commands.interrupt_calls)
        end)

        it("prompts for a slot when none is given", function()
            vim_mock.get().fn.getcharstr = function() return "1" end
            fake_state.terminals[1] = toggleterm_mock.make_terminal(true)

            terminal.close()

            assert.same({ 1 }, fake_commands.interrupt_calls)
        end)
    end)

    describe("close_all()", function()
        it("calls commands.interrupt for every slot", function()
            fake_state.terminals = {
                [1] = toggleterm_mock.make_terminal(true),
                [2] = toggleterm_mock.make_terminal(true),
            }

            terminal.close_all()

            table.sort(fake_commands.interrupt_calls)
            assert.same({ 1, 2 }, fake_commands.interrupt_calls)
        end)

        it("does nothing when there are no terminals", function()
            terminal.close_all()
            assert.equal(0, #fake_commands.interrupt_calls)
        end)
    end)
end)
