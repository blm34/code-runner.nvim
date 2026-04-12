local vim_mock = require("helpers.vim_mock")

-- ---------------------------------------------------------------------------
-- Fakes
-- ---------------------------------------------------------------------------

local function install_fake_config()
    local fake = { setup_calls = {} }
    function fake.setup(opts) table.insert(fake.setup_calls, opts) end

    package.loaded["code-runner.config"] = fake
    return fake
end

local function install_fake_executor()
    local fake = {
        run_current_file_calls       = {},
        run_file_from_register_calls = {},
        rerun_last_calls             = {},
        save_current_file_path_calls = {},
    }
    function fake.run_current_file(new_terminal)
        table.insert(fake.run_current_file_calls, new_terminal)
    end

    function fake.run_file_from_register(opts)
        table.insert(fake.run_file_from_register_calls, opts)
    end

    function fake.rerun_last(new_terminal)
        table.insert(fake.rerun_last_calls, new_terminal)
    end

    function fake.save_current_file_path_to_register(register)
        table.insert(fake.save_current_file_path_calls, register)
    end

    package.loaded["code-runner.executor"] = fake
    return fake
end

local function install_fake_terminal()
    local fake = {
        toggle_calls     = {},
        toggle_all_calls = 0,
        close_calls      = {},
        close_all_calls  = 0,
    }
    function fake.toggle(slot) table.insert(fake.toggle_calls, slot) end

    function fake.toggle_all() fake.toggle_all_calls = fake.toggle_all_calls + 1 end

    function fake.close(slot) table.insert(fake.close_calls, slot) end

    function fake.close_all() fake.close_all_calls = fake.close_all_calls + 1 end

    package.loaded["code-runner.terminal"] = fake
    return fake
end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

describe("code-runner", function()
    local code_runner
    local fake_config
    local fake_executor
    local fake_terminal

    before_each(function()
        vim_mock.setup()

        fake_config                   = install_fake_config()
        fake_executor                 = install_fake_executor()
        fake_terminal                 = install_fake_terminal()

        package.loaded["code-runner"] = nil
        code_runner                   = require("code-runner")
    end)

    after_each(function()
        package.loaded["code-runner.config"]   = nil
        package.loaded["code-runner.executor"] = nil
        package.loaded["code-runner.terminal"] = nil
        vim_mock.teardown()
    end)

    describe("setup()", function()
        it("calls config.setup with the given opts", function()
            code_runner.setup({ max_slots = 5 })
            assert.same({ { max_slots = 5 } }, fake_config.setup_calls)
        end)

        it("calls config.setup with nil when called with no args", function()
            code_runner.setup()
            assert.same({ nil }, fake_config.setup_calls)
        end)
    end)

    describe("run_current_file()", function()
        it("calls executor.run_current_file with false when called with no args", function()
            code_runner.run_current_file()
            assert.same({ false }, fake_executor.run_current_file_calls)
        end)

        it("passes new_terminal = false when explicitly false", function()
            code_runner.run_current_file(false)
            assert.same({ false }, fake_executor.run_current_file_calls)
        end)

        it("passes new_terminal = true when true", function()
            code_runner.run_current_file(true)
            assert.same({ true }, fake_executor.run_current_file_calls)
        end)
    end)

    describe("run_file_from_register()", function()
        it("forwards opts to executor.run_file_from_register", function()
            local opts = { register = "a", new_terminal = false }
            code_runner.run_file_from_register(opts)
            assert.same({ opts }, fake_executor.run_file_from_register_calls)
        end)

        it("forwards nil opts unchanged", function()
            code_runner.run_file_from_register(nil)
            assert.same({ nil }, fake_executor.run_file_from_register_calls)
        end)
    end)

    describe("rerun_last_command()", function()
        it("calls executor.rerun_last with false when called with no args", function()
            code_runner.rerun_last_command()
            assert.same({ false }, fake_executor.rerun_last_calls)
        end)

        it("passes new_terminal = true when true", function()
            code_runner.rerun_last_command(true)
            assert.same({ true }, fake_executor.rerun_last_calls)
        end)

        it("passes new_terminal = false when explicitly false", function()
            code_runner.rerun_last_command(false)
            assert.same({ false }, fake_executor.rerun_last_calls)
        end)
    end)

    describe("save_current_file_path_to_register()", function()
        it("forwards the register to executor", function()
            code_runner.save_current_file_path_to_register("a")
            assert.same({ "a" }, fake_executor.save_current_file_path_calls)
        end)

        it("forwards nil when no register given", function()
            code_runner.save_current_file_path_to_register()
            assert.same({ nil }, fake_executor.save_current_file_path_calls)
        end)
    end)

    describe("toggle_terminal()", function()
        it("forwards the slot to terminal.toggle", function()
            code_runner.toggle_terminal(2)
            assert.same({ 2 }, fake_terminal.toggle_calls)
        end)

        it("forwards nil when no slot given", function()
            code_runner.toggle_terminal()
            assert.same({ nil }, fake_terminal.toggle_calls)
        end)
    end)

    describe("toggle_all_terminals()", function()
        it("calls terminal.toggle_all once", function()
            code_runner.toggle_all_terminals()
            assert.equal(1, fake_terminal.toggle_all_calls)
        end)
    end)

    describe("close_terminal()", function()
        it("forwards the slot to terminal.close", function()
            code_runner.close_terminal(3)
            assert.same({ 3 }, fake_terminal.close_calls)
        end)

        it("forwards nil when no slot given", function()
            code_runner.close_terminal()
            assert.same({ nil }, fake_terminal.close_calls)
        end)
    end)

    describe("close_all_terminals()", function()
        it("calls terminal.close_all once", function()
            code_runner.close_all_terminals()
            assert.equal(1, fake_terminal.close_all_calls)
        end)
    end)
end)
