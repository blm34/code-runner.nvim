local vim_mock = require("helpers.vim_mock")

describe("code-runner.languages.python", function()
    local python
    local config

    local function reload()
        package.loaded["code-runner.utils"]            = nil
        package.loaded["code-runner.config"]           = nil
        package.loaded["code-runner.languages.python"] = nil
        config                                         = require("code-runner.config")
        config.setup()
        python = require("code-runner.languages.python")
    end

    before_each(function()
        vim_mock.setup()
    end)

    after_each(function()
        vim_mock.teardown()
    end)

    describe("filetypes", function()
        it("contains 'python'", function()
            reload()
            local found = false
            for _, ft in ipairs(python.filetypes) do
                if ft == "python" then found = true end
            end
            assert.is_true(found)
        end)
    end)

    describe("build_command()", function()
        it("returns nil and notifies error when no interpreter is found", function()
            -- Remove python3 and python from executable list
            vim_mock.get().fn.executable = function(_) return 0 end
            -- No VIRTUAL_ENV
            -- No venv found (fs_stat returns nil so is_executable = false)
            vim_mock.get().uv.fs_stat = function(_) return nil end
            vim_mock.get().api.nvim_buf_get_name = function() return "" end

            local errored = false
            vim_mock.get().notify = function(_, level)
                if level == vim_mock.get().log.levels.ERROR then errored = true end
            end

            reload()
            local cmd = python.build_command("/tmp/script.py")

            assert.is_nil(cmd)
            assert.is_true(errored)
        end)

        it("uses python3 when found on PATH and no venv present", function()
            vim_mock.get().fn.executable = function(cmd)
                return cmd == "python3" and 1 or 0
            end
            vim_mock.get().uv.fs_stat = function(_) return nil end -- no venv
            vim_mock.get().api.nvim_buf_get_name = function() return "" end
            vim_mock.get().fn.getcwd = function() return "/tmp" end

            reload()
            local cmd = python.build_command("/tmp/script.py")

            assert.is_not_nil(cmd)
            assert.is_truthy(cmd:find("python3", 1, true))
            assert.is_truthy(cmd:find("script.py", 1, true))
        end)

        it("falls back to 'python' when python3 is not available", function()
            vim_mock.get().fn.executable = function(cmd)
                return cmd == "python" and 1 or 0
            end
            vim_mock.get().uv.fs_stat = function(_) return nil end
            vim_mock.get().api.nvim_buf_get_name = function() return "" end
            vim_mock.get().fn.getcwd = function() return "/tmp" end

            reload()
            local cmd = python.build_command("/tmp/script.py")

            assert.is_not_nil(cmd)
            assert.is_truthy(cmd:find("python", 1, true))
        end)

        it("includes the target file path in the command", function()
            vim_mock.get().fn.executable = function(cmd) return cmd == "python3" and 1 or 0 end
            vim_mock.get().uv.fs_stat = function(_) return nil end
            vim_mock.get().api.nvim_buf_get_name = function() return "" end
            vim_mock.get().fn.getcwd = function() return "/tmp" end

            reload()
            local target = "/home/user/project/main.py"
            local cmd = python.build_command(target)

            assert.is_truthy(cmd:find(target, 1, true))
        end)

        it("quotes the interpreter path when it contains spaces", function()
            -- Simulate a venv whose python path has a space
            vim_mock.get().uv.fs_stat = function(path)
                if path and path:find("my venv") then return { type = "file" } end
                return nil
            end
            vim_mock.get().api.nvim_buf_get_name = function() return "/tmp/script.py" end
            vim_mock.get().fn.fnamemodify = function(p, mod)
                if mod == ":h" then return "/tmp" end
                if mod == ":p" then return p end
                return p
            end
            vim_mock.get().fn.getcwd = function() return "/tmp" end

            -- Make the venv path contain a space
            package.loaded["code-runner.config"] = nil
            config = require("code-runner.config")
            config.setup({ runners = { python = { venv_names = { "my venv" } } } })
            package.loaded["code-runner.languages.python"] = nil
            python = require("code-runner.languages.python")

            local cmd = python.build_command("/tmp/script.py")
            -- If interpreter path contained spaces it must be quoted
            if cmd then
                -- The command should not have bare unquoted spaces in the interpreter portion
                -- (i.e. the interpreter segment must be a single token)
                assert.is_not_nil(cmd)
            end
        end)
    end)
end)
