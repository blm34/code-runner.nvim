local vim_mock = require("helpers.vim_mock")

describe("code-runner.executor.registers", function()
    local registers

    before_each(function()
        vim_mock.setup()
        package.loaded["code-runner.executor.registers"] = nil
        registers = require("code-runner.executor.registers")
    end)

    after_each(function()
        vim_mock.teardown()
    end)

    describe("get_path_from_register()", function()
        it("returns nil and warns when register is empty", function()
            local warned             = false
            vim_mock.get().fn.getreg = function(_) return "" end
            vim_mock.get().notify    = function(_, level)
                if level == vim_mock.get().log.levels.WARN then warned = true end
            end

            local result             = registers.get_path_from_register("a")

            assert.is_nil(result)
            assert.is_true(warned)
        end)

        it("returns nil and errors when file is not readable", function()
            local errored                  = false
            vim_mock.get().fn.getreg       = function(_) return "/nonexistent/file.py" end
            vim_mock.get().fn.filereadable = function(_) return 0 end
            vim_mock.get().notify          = function(_, level)
                if level == vim_mock.get().log.levels.ERROR then errored = true end
            end

            local result                   = registers.get_path_from_register("a")

            assert.is_nil(result)
            assert.is_true(errored)
        end)

        it("returns the path when register contains a readable file", function()
            vim_mock.get().fn.getreg       = function(_) return "/tmp/script.py" end
            vim_mock.get().fn.filereadable = function(_) return 1 end

            local result                   = registers.get_path_from_register("a")

            assert.equal("/tmp/script.py", result)
        end)

        it("strips trailing whitespace from the register value", function()
            vim_mock.get().fn.getreg       = function(_) return "/tmp/script.py   " end
            vim_mock.get().fn.filereadable = function(_) return 1 end

            local result                   = registers.get_path_from_register("a")

            assert.equal("/tmp/script.py", result)
        end)
    end)

    describe("get_registers_containing_filepaths()", function()
        it("returns an empty list when all registers are empty", function()
            vim_mock.get().fn.getreg = function(_) return "" end

            local result = registers.get_registers_containing_filepaths({ python = true })

            assert.same({}, result)
        end)

        it("returns an empty list when files are not readable", function()
            vim_mock.get().fn.getreg       = function(_) return "/tmp/script.py" end
            vim_mock.get().fn.filereadable = function(_) return 0 end

            local result                   = registers.get_registers_containing_filepaths({ python = true })

            assert.same({}, result)
        end)

        it("returns an empty list when filetypes are not supported", function()
            -- register contains a .lua file but only python is supported
            vim_mock.get().fn.getreg       = function(r) return r == "a" and "/tmp/script.lua" or "" end
            vim_mock.get().fn.filereadable = function(_) return 1 end
            vim_mock.get().filetype.match  = function(opts)
                if opts.filename:match("%.lua$") then return "lua" end
                return nil
            end

            local result                   = registers.get_registers_containing_filepaths({ python = true })

            assert.same({}, result)
        end)

        it("returns matching entries for supported filetypes", function()
            vim_mock.get().fn.getreg       = function(r)
                if r == "a" then return "/tmp/script.py" end
                if r == "b" then return "/tmp/other.py" end
                return ""
            end
            vim_mock.get().fn.filereadable = function(_) return 1 end
            vim_mock.get().filetype.match  = function(opts)
                if opts.filename:match("%.py$") then return "python" end
                return nil
            end

            local result                   = registers.get_registers_containing_filepaths({ python = true })

            assert.equal(2, #result)
        end)

        it("each entry has reg, path, and label fields", function()
            vim_mock.get().fn.getreg       = function(r) return r == "a" and "/tmp/s.py" or "" end
            vim_mock.get().fn.filereadable = function(_) return 1 end
            vim_mock.get().filetype.match  = function(_) return "python" end

            local result                   = registers.get_registers_containing_filepaths({ python = true })

            assert.equal(1, #result)
            assert.equal("a", result[1].reg)
            assert.equal("/tmp/s.py", result[1].path)
            assert.is_string(result[1].label)
            assert.is_truthy(result[1].label:find("@a"))
        end)

        it("includes the path in the label", function()
            vim_mock.get().fn.getreg       = function(r) return r == "c" and "/tmp/main.py" or "" end
            vim_mock.get().fn.filereadable = function(_) return 1 end
            vim_mock.get().filetype.match  = function(_) return "python" end

            local result                   = registers.get_registers_containing_filepaths({ python = true })

            assert.is_truthy(result[1].label:find("/tmp/main.py", 1, true))
        end)

        it("strips newlines from register content", function()
            vim_mock.get().fn.getreg       = function(r) return r == "a" and "/tmp/s.py\n" or "" end
            vim_mock.get().fn.filereadable = function(_) return 1 end
            vim_mock.get().filetype.match  = function(_) return "python" end

            local result                   = registers.get_registers_containing_filepaths({ python = true })

            assert.equal(1, #result)
            assert.equal("/tmp/s.py", result[1].path)
        end)
    end)

    describe("select_register_and_run()", function()
        it("warns and does not call runner_func when registers list is empty", function()
            local warned = false
            local called = false
            vim_mock.get().notify = function(_, level)
                if level == vim_mock.get().log.levels.WARN then warned = true end
            end

            registers.select_register_and_run({}, function() called = true end)

            assert.is_true(warned)
            assert.is_false(called)
        end)

        it("calls runner_func with the selected path", function()
            local received_path = nil
            -- mock ui.select to auto-pick the first item
            vim_mock.get().ui.select = function(items, _, cb) cb(items[1]) end

            local entries = {
                { reg = "a", path = "/tmp/a.py", label = "@a: /tmp/a.py" },
                { reg = "b", path = "/tmp/b.py", label = "@b: /tmp/b.py" },
            }
            registers.select_register_and_run(entries, function(p) received_path = p end)

            assert.equal("/tmp/a.py", received_path)
        end)

        it("does not call runner_func when user cancels (nil choice)", function()
            local called = false
            vim_mock.get().ui.select = function(_, _, cb) cb(nil) end

            local entries = { { reg = "a", path = "/tmp/a.py", label = "@a" } }
            registers.select_register_and_run(entries, function() called = true end)

            assert.is_false(called)
        end)

        it("sorts entries by register name before presenting them", function()
            -- Capture the items passed to ui.select
            local presented = nil
            vim_mock.get().ui.select = function(items, _, cb)
                presented = items
                cb(nil) -- cancel; we just want to inspect order
            end

            local entries = {
                { reg = "c", path = "/tmp/c.py", label = "@c" },
                { reg = "a", path = "/tmp/a.py", label = "@a" },
                { reg = "b", path = "/tmp/b.py", label = "@b" },
            }
            registers.select_register_and_run(entries, function() end)

            assert.equal("a", presented[1].reg)
            assert.equal("b", presented[2].reg)
            assert.equal("c", presented[3].reg)
        end)
    end)
end)
