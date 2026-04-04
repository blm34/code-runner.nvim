local vim_mock = require("helpers.vim_mock")

describe("code-runner.utils", function()
    local utils

    before_each(function()
        vim_mock.setup()
        package.loaded["code-runner.utils"] = nil
        utils = require("code-runner.utils")
    end)

    after_each(function()
        vim_mock.teardown()
    end)

    describe("is_windows", function()
        it("returns false when vim.fn.has('win32') == 0", function()
            vim_mock.get().fn.has = function(_) return 0 end
            package.loaded["code-runner.utils"] = nil
            utils = require("code-runner.utils")
            assert.is_false(utils.is_windows)
        end)

        it("returns true when vim.fn.has('win32') == 1", function()
            vim_mock.get().fn.has = function(_) return 1 end
            package.loaded["code-runner.utils"] = nil
            utils = require("code-runner.utils")
            assert.is_true(utils.is_windows)
        end)
    end)

    describe("is_pwsh", function()
        it("returns true when vim.o.shell=powershell", function()
            vim_mock.get().o.shell = "powershell"
            package.loaded["code-runner.utils"] = nil
            utils = require("code-runner.utils")
            assert.is_true(utils.is_pwsh)
        end)

        it("returns true when vim.o.shell=pwsh", function()
            vim_mock.get().o.shell = "pwsh"
            package.loaded["code-runner.utils"] = nil
            utils = require("code-runner.utils")
            assert.is_true(utils.is_pwsh)
        end)

        it("returns true when vim.o.shell contains powershell path", function()
            vim_mock.get().o.shell = "programs\\path\\powershell"
            package.loaded["code-runner.utils"] = nil
            utils = require("code-runner.utils")
            assert.is_true(utils.is_pwsh)
        end)

        it("returns true when vim.o.shell contains pwsh path", function()
            vim_mock.get().o.shell = "programs\\path\\pwsh"
            package.loaded["code-runner.utils"] = nil
            utils = require("code-runner.utils")
            assert.is_true(utils.is_pwsh)
        end)

        it("returns false when vim.o.shell=cmd", function()
            vim_mock.get().o.shell = "cmd"
            package.loaded["code-runner.utils"] = nil
            utils = require("code-runner.utils")
            assert.is_false(utils.is_pwsh)
        end)
    end)

    describe("is_executable", function()
        it("returns false for nil", function()
            assert.is_false(utils.is_executable(nil))
        end)

        it("returns false for empty string", function()
            assert.is_false(utils.is_executable(""))
        end)

        it("returns true when vim.uv.fs_stat returns a result", function()
            vim_mock.get().uv.fs_stat = function(_) return { type = "file" } end
            assert.is_true(utils.is_executable("/usr/bin/python"))
        end)

        it("returns false when vim.uv.fs_stat returns nil", function()
            vim_mock.get().uv.fs_stat = function(_) return nil end
            assert.is_false(utils.is_executable("/nonexistent/path"))
        end)
    end)

    describe("escape_arg (Unix)", function()
        before_each(function()
            vim_mock.get().fn.has = function(_) return 0 end
            package.loaded["code-runner.utils"] = nil
            utils = require("code-runner.utils")
        end)

        it("returns the argument unchanged when it contains no spaces", function()
            assert.equal("python3", utils.escape_arg("python3"))
        end)

        it("returns the argument unchanged for a path without spaces", function()
            assert.equal("/usr/bin/python3", utils.escape_arg("/usr/bin/python3"))
        end)

        it("wraps argument in single quotes when it contains a space", function()
            local result = utils.escape_arg("/my path/python")
            assert.equal("'/my path/python'", result)
        end)

        it("escapes single quotes inside the argument", function()
            local result = utils.escape_arg("/path/with'quote/python")
            assert.equal("'/path/with'\\''quote/python'", result)
        end)

        it("wraps in quotes when special characters are in the argument", function()
            local result = utils.escape_arg("path/my$file")
            assert.equal("'path/my$file'", result)
        end)

        it("wraps an empty string with single quotes", function()
            local result = utils.escape_arg("")
            assert.equal("''", result)
        end)

        it("wraps and escapes a lone single quote", function()
            local result = utils.escape_arg("'")
            assert.equal("''\\'''", result)
        end)

        it("escapes multiple single quotes", function()
            local result = utils.escape_arg("it's a \"test\"")
            assert.equal("'it'\\''s a \"test\"'", result)
        end)
    end)

    describe("escape_arg (Windows Powershell)", function()
        before_each(function()
            vim_mock.get().fn.has = function(_) return 1 end
            vim_mock.get().o.shell = "pwsh"
            package.loaded["code-runner.utils"] = nil
            utils = require("code-runner.utils")
        end)

        it("returns the argument unchanged when no spaces", function()
            assert.equal("python", utils.escape_arg("python"))
        end)

        it("wraps argument in single quotes on Windows when it contains a space", function()
            local result = utils.escape_arg("C:\\Program Files\\python")
            assert.equal("'C:\\Program Files\\python'", result)
        end)

        it("wraps an empty string", function()
            local result = utils.escape_arg("")
            assert.equal("''", result)
        end)

        it("escapes unsafe characters and wraps in single quotes", function()
            local result = utils.escape_arg("unsafe`param'chars$")
            assert.equal("'unsafe``param''chars`$'", result)
        end)

        it("escapes a lone backtick", function()
            local result = utils.escape_arg("`")
            assert.equal("'``'", result)
        end)

        it("escapes a lone dollar", function()
            local result = utils.escape_arg("$")
            assert.equal("'`$'", result)
        end)

        it("escapes embedded double quotes", function()
            local result = utils.escape_arg("This is \"a\" string")
            assert.equal("'This is `\"a`\" string'", result)
        end)
    end)

    describe("escape_arg (Windows CMD)", function()
        before_each(function()
            vim_mock.get().fn.has = function(_) return 1 end
            vim_mock.get().o.shell = "cmd"
            package.loaded["code-runner.utils"] = nil
            utils = require("code-runner.utils")
        end)

        it("returns the argument unchanged when no spaces", function()
            assert.equal("python", utils.escape_arg("python"))
        end)

        it("wraps argument in double quotes on Windows when it contains a space", function()
            local result = utils.escape_arg("C:\\Program Files\\python")
            assert.equal('"C:\\Program Files\\python"', result)
        end)

        it("escapes special characters and wraps in double quotes", function()
            local result = utils.escape_arg("unsafe>characters|")
            assert.equal('"unsafe^>characters^|"', result)
        end)

        it("wraps an empty string", function()
            local result = utils.escape_arg("")
            assert.equal('""', result)
        end)

        it("escapes embedded double quotes", function()
            local result = utils.escape_arg("This is \"a\" string")
            assert.equal('"This is \"\"a\"\" string"', result)
        end)

        it("escapes a lone carat", function()
            local result = utils.escape_arg("^")
            assert.equal('"^^"', result)
        end)
    end)
end)
