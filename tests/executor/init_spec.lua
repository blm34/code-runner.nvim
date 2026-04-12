local vim_mock = require("helpers.vim_mock")

-- ---------------------------------------------------------------------------
-- Fakes
-- ---------------------------------------------------------------------------

local function install_fake_core()
    local fake = {
        run_file_calls                   = {},
        run_file_in_new_terminal_calls   = {},
        rerun_last_calls                 = 0,
        rerun_last_in_new_terminal_calls = 0,
        supported_filetypes              = { python = true },
    }
    function fake.run_file(path)
        table.insert(fake.run_file_calls, path)
    end

    function fake.run_file_in_new_terminal(path)
        table.insert(fake.run_file_in_new_terminal_calls, path)
    end

    function fake.rerun_last()
        fake.rerun_last_calls = fake.rerun_last_calls + 1
    end

    function fake.rerun_last_in_new_terminal()
        fake.rerun_last_in_new_terminal_calls = fake.rerun_last_in_new_terminal_calls + 1
    end

    function fake.get_supported_filetypes()
        return fake.supported_filetypes
    end

    package.loaded["code-runner.executor.core"] = fake
    return fake
end

local function install_fake_registers()
    local fake = {
        get_path_calls       = {},
        get_registers_calls  = {},
        select_and_run_calls = {},
        -- defaults that tests can override
        path_to_return       = "/tmp/pinned.py",
        registers_to_return  = {},
    }
    function fake.get_path_from_register(reg)
        table.insert(fake.get_path_calls, reg)
        return fake.path_to_return
    end

    function fake.get_registers_containing_filepaths(fts)
        table.insert(fake.get_registers_calls, fts)
        return fake.registers_to_return
    end

    function fake.select_register_and_run(regs, runner_fn)
        table.insert(fake.select_and_run_calls, { regs = regs, runner_fn = runner_fn })
    end

    package.loaded["code-runner.executor.registers"] = fake
    return fake
end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

describe("code-runner.executor", function()
    local executor
    local fake_core
    local fake_registers

    before_each(function()
        vim_mock.setup()
        -- default: expand returns a readable file path
        vim_mock.get().fn.expand               = function(_) return "/tmp/current.py" end
        vim_mock.get().fn.filereadable         = function(_) return 1 end

        fake_core                              = install_fake_core()
        fake_registers                         = install_fake_registers()

        package.loaded["code-runner.executor"] = nil
        executor                               = require("code-runner.executor")
    end)

    after_each(function()
        package.loaded["code-runner.executor.core"]      = nil
        package.loaded["code-runner.executor.registers"] = nil
        vim_mock.teardown()
    end)

    describe("run_current_file()", function()
        it("calls core.run_file with the current file path", function()
            executor.run_current_file(false)
            assert.same({ "/tmp/current.py" }, fake_core.run_file_calls)
        end)

        it("calls core.run_file_in_new_terminal when new_terminal is true", function()
            executor.run_current_file(true)
            assert.same({ "/tmp/current.py" }, fake_core.run_file_in_new_terminal_calls)
        end)

        it("does not call run_file_in_new_terminal when new_terminal is false", function()
            executor.run_current_file(false)
            assert.equal(0, #fake_core.run_file_in_new_terminal_calls)
        end)

        it("does not call run_file when new_terminal is true", function()
            executor.run_current_file(true)
            assert.equal(0, #fake_core.run_file_calls)
        end)

        it("warns and does nothing when the buffer has no path", function()
            local warned = false
            vim_mock.get().fn.expand = function(_) return "" end
            vim_mock.get().notify = function(_, level)
                if level == vim_mock.get().log.levels.WARN then warned = true end
            end

            executor.run_current_file(false)

            assert.is_true(warned)
            assert.equal(0, #fake_core.run_file_calls)
        end)

        it("warns and does nothing when the file is not readable", function()
            local warned = false
            vim_mock.get().fn.filereadable = function(_) return 0 end
            vim_mock.get().notify = function(_, level)
                if level == vim_mock.get().log.levels.WARN then warned = true end
            end

            executor.run_current_file(false)

            assert.is_true(warned)
            assert.equal(0, #fake_core.run_file_calls)
        end)
    end)

    describe("run_file_from_register()", function()
        describe("with a register specified", function()
            it("looks up the path from the given register", function()
                executor.run_file_from_register({ register = "a" })
                assert.same({ "a" }, fake_registers.get_path_calls)
            end)

            it("calls core.run_file with the path from the register", function()
                executor.run_file_from_register({ register = "a" })
                assert.same({ "/tmp/pinned.py" }, fake_core.run_file_calls)
            end)

            it("calls core.run_file_in_new_terminal when new_terminal is true", function()
                executor.run_file_from_register({ register = "a", new_terminal = true })
                assert.same({ "/tmp/pinned.py" }, fake_core.run_file_in_new_terminal_calls)
            end)

            it("does not call run_file when new_terminal is true", function()
                executor.run_file_from_register({ register = "a", new_terminal = true })
                assert.equal(0, #fake_core.run_file_calls)
            end)

            it("does not call run_file when register returns nil path", function()
                fake_registers.path_to_return = nil
                executor.run_file_from_register({ register = "a" })
                assert.equal(0, #fake_core.run_file_calls)
            end)

            it("does not call select_register_and_run", function()
                executor.run_file_from_register({ register = "a" })
                assert.equal(0, #fake_registers.select_and_run_calls)
            end)
        end)

        describe("run_file_from_register() without a register specified", function()
            it("queries supported filetypes from core", function()
                executor.run_file_from_register({})
                assert.equal(1, #fake_registers.get_registers_calls)
            end)

            it("passes supported filetypes to get_registers_containing_filepaths", function()
                executor.run_file_from_register({})
                assert.same(fake_core.supported_filetypes, fake_registers.get_registers_calls[1])
            end)

            it("calls select_register_and_run with the register list", function()
                local regs = { { reg = "a", path = "/tmp/a.py", label = "@a" } }
                fake_registers.registers_to_return = regs
                executor.run_file_from_register({})
                assert.equal(1, #fake_registers.select_and_run_calls)
                assert.same(regs, fake_registers.select_and_run_calls[1].regs)
            end)

            it("passes core.run_file as the runner function", function()
                executor.run_file_from_register({})
                local runner_fn = fake_registers.select_and_run_calls[1].runner_fn
                assert.equal(fake_core.run_file, runner_fn)
            end)

            it("passes core.run_file_in_new_terminal when new_terminal is true", function()
                executor.run_file_from_register({ new_terminal = true })
                local runner_fn = fake_registers.select_and_run_calls[1].runner_fn
                assert.equal(fake_core.run_file_in_new_terminal, runner_fn)
            end)

            it("defaults new_terminal to false when opts is nil", function()
                executor.run_file_from_register()
                local runner_fn = fake_registers.select_and_run_calls[1].runner_fn
                assert.equal(fake_core.run_file, runner_fn)
            end)
        end)
    end)

    describe("save_current_file_path_to_register()", function()
        it("saves the current file path to the given register", function()
            local saved_reg, saved_val
            vim_mock.get().fn.setreg = function(reg, val)
                saved_reg = reg
                saved_val = val
            end

            executor.save_current_file_path_to_register("a")

            assert.equal("a", saved_reg)
            assert.equal("/tmp/current.py", saved_val)
        end)

        it("prompts for a register when none is given", function()
            local prompted = false
            vim_mock.get().fn.input = function(_)
                prompted = true
                return "b"
            end

            executor.save_current_file_path_to_register()

            assert.is_true(prompted)
        end)

        it("uses the register returned by the prompt", function()
            local saved_reg
            vim_mock.get().fn.input  = function(_) return "b" end
            vim_mock.get().fn.setreg = function(reg, _) saved_reg = reg end

            executor.save_current_file_path_to_register()

            assert.equal("b", saved_reg)
        end)

        it("does nothing when the prompt is cancelled (empty string)", function()
            local setreg_called      = false
            vim_mock.get().fn.input  = function(_) return "" end
            vim_mock.get().fn.setreg = function() setreg_called = true end

            executor.save_current_file_path_to_register()

            assert.is_false(setreg_called)
        end)

        it("warns when the register is not a single a-z letter", function()
            local warned = false
            vim_mock.get().notify = function(_, level)
                if level == vim_mock.get().log.levels.WARN then warned = true end
            end

            executor.save_current_file_path_to_register("1")

            assert.is_true(warned)
        end)

        it("does not save when the register is invalid", function()
            local setreg_called = false
            vim_mock.get().fn.setreg = function() setreg_called = true end

            executor.save_current_file_path_to_register("!")

            assert.is_false(setreg_called)
        end)

        it("does nothing when there is no readable current file", function()
            local setreg_called = false
            vim_mock.get().fn.filereadable = function(_) return 0 end
            vim_mock.get().fn.setreg = function() setreg_called = true end

            executor.save_current_file_path_to_register("a")

            assert.is_false(setreg_called)
        end)

        it("emits an info notification on success", function()
            local notified = false
            vim_mock.get().notify = function(_, level)
                if level == nil or level == vim_mock.get().log.levels.INFO then
                    notified = true
                end
            end

            executor.save_current_file_path_to_register("a")

            assert.is_true(notified)
        end)
    end)

    describe("rerun_last()", function()
        it("calls core.rerun_last when new_terminal is false", function()
            executor.rerun_last(false)
            assert.equal(1, fake_core.rerun_last_calls)
        end)

        it("calls core.rerun_last_in_new_terminal when new_terminal is true", function()
            executor.rerun_last(true)
            assert.equal(1, fake_core.rerun_last_in_new_terminal_calls)
        end)

        it("does not call rerun_last_in_new_terminal when new_terminal is false", function()
            executor.rerun_last(false)
            assert.equal(0, fake_core.rerun_last_in_new_terminal_calls)
        end)

        it("does not call rerun_last when new_terminal is true", function()
            executor.rerun_last(true)
            assert.equal(0, fake_core.rerun_last_calls)
        end)
    end)
end)
