local vim_mock = require("helpers.vim_mock")
local toggleterm_mock = require("helpers.toggleterm_mock")

describe("code-runner.terminal.commands", function()
    local commands
    local state

    before_each(function()
        vim_mock.setup()
        toggleterm_mock.setup()

        package.loaded["code-runner.utils"]             = nil
        package.loaded["code-runner.config"]            = nil
        package.loaded["code-runner.terminal.shell"]    = nil
        package.loaded["code-runner.terminal.state"]    = nil
        package.loaded["code-runner.terminal.commands"] = nil

        state                                           = require("code-runner.terminal.state")
        commands                                        = require("code-runner.terminal.commands")

        state.terminals                                 = {}
    end)

    after_each(function()
        toggleterm_mock.teardown()
        vim_mock.teardown()
    end)

    describe("send()", function()
        it("creates a terminal when the slot is empty", function()
            commands.send(1, "python /tmp/script.py")
            assert.is_not_nil(state.terminals[1])
        end)

        it("opens the terminal when it is not already open", function()
            local term = toggleterm_mock.make_terminal(false)
            state.terminals[1] = term
            commands.send(1, "python /tmp/script.py")
            assert.equal(1, term._open_count)
        end)

        it("does not re-open the terminal when it is already open", function()
            local term = toggleterm_mock.make_terminal(true)
            state.terminals[1] = term
            commands.send(1, "python /tmp/script.py")
            assert.equal(0, term._open_count)
        end)

        it("sends a command string to the terminal", function()
            local term = toggleterm_mock.make_terminal(true)
            state.terminals[1] = term
            commands.send(1, "python /tmp/script.py")
            assert.equal(1, #term._send_args)
        end)

        it("includes the user command somewhere in what is sent", function()
            local term = toggleterm_mock.make_terminal(true)
            state.terminals[1] = term
            local user_cmd = "python /tmp/unique_script.py"
            commands.send(1, user_cmd)
            local sent = term._send_args[1].cmd
            assert.is_truthy(sent:find(user_cmd, 1, true))
        end)

        it("includes a clear command before the user command", function()
            local term = toggleterm_mock.make_terminal(true)
            state.terminals[1] = term
            commands.send(1, "echo hi")
            local sent = term._send_args[1].cmd
            assert.is_truthy(sent:find("clear", 1, true))
        end)

        it("includes a touch/sentinel command after the user command", function()
            local term = toggleterm_mock.make_terminal(true)
            state.terminals[1] = term
            commands.send(1, "echo hi")
            local sent = term._send_args[1].cmd
            assert.is_truthy(sent:find("touch", 1, true))
        end)

        it("deletes the sentinel file before sending", function()
            local deleted = {}
            vim_mock.get().fn.delete = function(p) table.insert(deleted, p) end
            local term = toggleterm_mock.make_terminal(true)
            state.terminals[1] = term
            commands.send(1, "echo hi")
            assert.equal(1, #deleted)
        end)
    end)

    -- ----------------------------------------------------------------
    -- interrupt()
    -- ----------------------------------------------------------------
    describe("interrupt()", function()
        it("does nothing when the slot has no terminal", function()
            assert.has_no.error(function()
                commands.interrupt(99)
            end)
        end)

        it("calls shutdown on the terminal", function()
            local term = toggleterm_mock.make_terminal(true)
            state.terminals[1] = term
            commands.interrupt(1)
            assert.equal(1, term._shutdown_calls)
        end)

        it("removes the terminal from the state table", function()
            toggleterm_mock.make_terminal(true)
            commands.interrupt(1)
            assert.is_nil(state.terminals[1])
        end)

        it("writes an empty sentinel file after shutdown", function()
            local written = {}
            vim_mock.get().fn.writefile = function(_, p) table.insert(written, p) end
            local term = toggleterm_mock.make_terminal(true)
            state.terminals[1] = term
            commands.interrupt(1)
            assert.equal(1, #written)
        end)
    end)

    -- ----------------------------------------------------------------
    -- interrupt_and_run()
    -- ----------------------------------------------------------------
    describe("interrupt_and_run()", function()
        it("interrupts the existing terminal and then runs the command", function()
            local term = toggleterm_mock.make_terminal(true)
            state.terminals[1] = term

            commands.interrupt_and_run(1, "python /tmp/new.py")

            -- Terminal was shut down
            assert.equal(1, term._shutdown_calls)
            -- A new terminal was created in slot 1 and received the command
            assert.is_not_nil(state.terminals[1])
            assert.equal(1, #state.terminals[1]._send_args)
        end)
    end)

    -- ----------------------------------------------------------------
    -- run_in_new_slot()
    -- ----------------------------------------------------------------
    describe("run_in_new_slot()", function()
        it("creates a terminal in the next available slot", function()
            state.terminals = {}
            -- next_slot returns 1 when empty
            commands.run_in_new_slot("python /tmp/script.py")
            assert.is_not_nil(state.terminals[1])
        end)
    end)

    -- ----------------------------------------------------------------
    -- apply_busy_behaviour()
    -- ----------------------------------------------------------------
    describe("apply_busy_behaviour()", function()
        it("does nothing for 'cancel' behaviour", function()
            local term = toggleterm_mock.make_terminal(true)
            state.terminals[1] = term
            commands.apply_busy_behaviour(1, "some cmd", "cancel")
            -- No shutdown, no new command
            assert.equal(0, term._shutdown_calls)
            assert.equal(0, #term._send_args)
        end)

        it("calls interrupt_and_run for 'interrupt' behaviour", function()
            local term = toggleterm_mock.make_terminal(true)
            state.terminals[1] = term
            commands.apply_busy_behaviour(1, "python /tmp/new.py", "interrupt")
            assert.equal(1, term._shutdown_calls)
        end)
    end)
end)
