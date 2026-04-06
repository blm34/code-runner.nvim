local vim_mock = require("helpers.vim_mock")

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Install a fake terminal module and return a table that records calls.
local function install_fake_terminal()
    local fake = {
        run_calls                 = {},
        run_in_new_terminal_calls = {},
    }
    function fake.run(cmd)
        table.insert(fake.run_calls, cmd)
    end

    function fake.run_in_new_terminal(cmd)
        table.insert(fake.run_in_new_terminal_calls, cmd)
    end

    package.loaded["code-runner.terminal"] = fake
    return fake
end

--- Install a fake python runner and return it.
--- build_command returns a predictable string so tests can assert on it.
local function install_fake_python_runner()
    local fake = {
        filetypes     = { "python" },
        build_command = function(path) return "python " .. path end,
    }
    package.loaded["code-runner.languages.python"] = fake
    return fake
end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

describe("code-runner.executor.core", function()
    local core
    local fake_terminal
    local fake_python

    before_each(function()
        vim_mock.setup()

        fake_terminal                               = install_fake_terminal()
        fake_python                                 = install_fake_python_runner()

        package.loaded["code-runner.executor.core"] = nil

        core                                        = require("code-runner.executor.core")
        core._reset_last_run_path()
    end)

    after_each(function()
        package.loaded["code-runner.terminal"]         = nil
        package.loaded["code-runner.languages.python"] = nil
        vim_mock.teardown()
    end)

    describe("get_supported_filetypes()", function()
        it("returns a table", function()
            assert.is_table(core.get_supported_filetypes())
        end)

        it("includes 'python'", function()
            assert.is_true(core.get_supported_filetypes()["python"])
        end)

        it("returns true as the value for each filetype", function()
            for _, v in pairs(core.get_supported_filetypes()) do
                assert.is_true(v)
            end
        end)

        it("reflects filetypes added by a runner", function()
            -- install a second fake runner for a new filetype
            fake_python.filetypes = { "python", "pyrex" }
            package.loaded["code-runner.executor.core"] = nil
            core = require("code-runner.executor.core")
            local fts = core.get_supported_filetypes()
            assert.is_true(fts["python"])
            assert.is_true(fts["pyrex"])
        end)
    end)

    describe("run_file()", function()
        it("calls terminal.run with the built command", function()
            core.run_file("/tmp/script.py")
            assert.equal(1, #fake_terminal.run_calls)
        end)

        it("passes the correct command to terminal.run", function()
            core.run_file("/tmp/script.py")
            assert.equal("python /tmp/script.py", fake_terminal.run_calls[1])
        end)

        it("does not call terminal.run when the filetype is unsupported", function()
            vim_mock.get().filetype.match = function(_) return "fake_language" end
            core.run_file("/tmp/script.rb")
            assert.equal(0, #fake_terminal.run_calls)
        end)

        it("does not call terminal.run when filetype cannot be detected", function()
            vim_mock.get().filetype.match = function(_) return nil end
            core.run_file("/tmp/script.py")
            assert.equal(0, #fake_terminal.run_calls)
        end)

        it("does not call terminal.run when build_command returns nil", function()
            fake_python.build_command = function(_) return nil end
            core.run_file("/tmp/script.py")
            assert.equal(0, #fake_terminal.run_calls)
        end)

        it("emits a WARN when the filetype cannot be detected", function()
            local warned = false
            vim_mock.get().filetype.match = function(_) return nil end
            vim_mock.get().notify = function(_, level)
                if level == vim_mock.get().log.levels.WARN then warned = true end
            end
            core.run_file("/tmp/script.py")
            assert.is_true(warned)
        end)

        it("emits a WARN when there is no runner for the filetype", function()
            local warned = false
            vim_mock.get().filetype.match = function(_) return "fake_language" end
            vim_mock.get().notify = function(_, level)
                if level == vim_mock.get().log.levels.WARN then warned = true end
            end
            core.run_file("/tmp/script.rb")
            assert.is_true(warned)
        end)

        it("does not call terminal.run_in_new_terminal", function()
            core.run_file("/tmp/script.py")
            assert.equal(0, #fake_terminal.run_in_new_terminal_calls)
        end)
    end)

    describe("run_file_in_new_terminal()", function()
        it("calls terminal.run_in_new_terminal with the built command", function()
            core.run_file_in_new_terminal("/tmp/script.py")
            assert.equal(1, #fake_terminal.run_in_new_terminal_calls)
        end)

        it("passes the correct command", function()
            core.run_file_in_new_terminal("/tmp/script.py")
            assert.equal("python /tmp/script.py", fake_terminal.run_in_new_terminal_calls[1])
        end)

        it("does not call terminal.run", function()
            core.run_file_in_new_terminal("/tmp/script.py")
            assert.equal(0, #fake_terminal.run_calls)
        end)

        it("does not call terminal.run_in_new_terminal when filetype is unsupported", function()
            vim_mock.get().filetype.match = function(_) return "fake_language" end
            core.run_file_in_new_terminal("/tmp/script.rb")
            assert.equal(0, #fake_terminal.run_in_new_terminal_calls)
        end)
    end)

    describe("rerun_last()", function()
        it("warns and does nothing when no file has been run yet", function()
            local warned = false
            vim_mock.get().notify = function(_, level)
                if level == vim_mock.get().log.levels.WARN then warned = true end
            end
            core.rerun_last()
            assert.is_true(warned)
            assert.equal(0, #fake_terminal.run_calls)
        end)

        it("re-runs the last file that was run", function()
            core.run_file("/tmp/script.py")
            fake_terminal.run_calls = {} -- clear so we can assert the rerun alone

            core.rerun_last()

            assert.equal(1, #fake_terminal.run_calls)
            assert.equal("python /tmp/script.py", fake_terminal.run_calls[1])
        end)

        it("uses the most recently run file, not an earlier one", function()
            core.run_file("/tmp/first.py")
            core.run_file("/tmp/second.py")
            fake_terminal.run_calls = {}

            core.rerun_last()

            assert.equal("python /tmp/second.py", fake_terminal.run_calls[1])
        end)

        it("does not call terminal.run_in_new_terminal", function()
            core.run_file("/tmp/script.py")
            fake_terminal.run_in_new_terminal_calls = {}

            core.rerun_last()

            assert.equal(0, #fake_terminal.run_in_new_terminal_calls)
        end)
    end)

    describe("rerun_last_in_new_terminal()", function()
        it("warns and does nothing when no file has been run yet", function()
            local warned = false
            vim_mock.get().notify = function(_, level)
                if level == vim_mock.get().log.levels.WARN then warned = true end
            end
            core.rerun_last_in_new_terminal()
            assert.is_true(warned)
            assert.equal(0, #fake_terminal.run_in_new_terminal_calls)
        end)

        it("re-runs the last file in a new terminal", function()
            core.run_file("/tmp/script.py")
            fake_terminal.run_in_new_terminal_calls = {}

            core.rerun_last_in_new_terminal()

            assert.equal(1, #fake_terminal.run_in_new_terminal_calls)
            assert.equal("python /tmp/script.py", fake_terminal.run_in_new_terminal_calls[1])
        end)

        it("does not call terminal.run", function()
            core.run_file("/tmp/script.py")
            fake_terminal.run_calls = {}

            core.rerun_last_in_new_terminal()

            assert.equal(0, #fake_terminal.run_calls)
        end)
    end)

    describe("_reset_last_run_path()", function()
        it("clears last_run_path", function()
            core.run_file("/tmp/script.py")
            assert.equal("/tmp/script.py", core.last_run_path)

            core._reset_last_run_path()
            assert.is_nil(core.last_run_path)
        end)
    end)
end)
