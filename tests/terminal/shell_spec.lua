local vim_mock = require("helpers.vim_mock")

describe("code-runner.terminal.shell", function()
    local shell

    ---Set the value of `is_windows` and `is_pwsh`
    ---@param is_windows boolean
    ---@param is_pwsh boolean
    local function load_shell_for(is_windows, is_pwsh)
        vim_mock.setup()
        local utils = require("code-runner.utils")
        utils.is_windows = is_windows
        utils.is_pwsh = is_pwsh
        package.loaded["code-runner.utils"] = utils
        package.loaded["code-runner.terminal.shell"] = nil
        shell = require("code-runner.terminal.shell")
    end

    before_each(function()
        vim_mock.setup()
        package.loaded["code-runner.terminal.shell"] = nil
        shell = require("code-runner.terminal.shell")
    end)

    after_each(function()
        vim_mock.teardown()
        package.loaded["code-runner.utils"] = nil
        package.loaded["code-runner.terminal.shell"] = nil
    end)

    describe("command_seperator()", function()
        it("returns ' ; ' on Unix (bash)", function()
            load_shell_for(false, false)
            assert.equal(" ; ", shell.command_seperator())
        end)

        it("returns ' ; ' on powershell", function()
            load_shell_for(true, true)
            assert.equal(" ; ", shell.command_seperator())
        end)

        it("returns ' & ' on windows (not powershell)", function()
            load_shell_for(true, false)
            assert.equal(" & ", shell.command_seperator())
        end)
    end)

    describe("touch_command()", function()
        it("returns 'touch <file>' on Unix", function()
            load_shell_for(false, false)
            local cmd = shell.touch_command("/tmp/sentinel.free")
            assert.truthy(cmd:match("^touch "))
        end)

        it("includes the file path verbatim on Unix", function()
            load_shell_for(false, false)
            local file = "/home/user/.cache/nvim/code-runner-slot-1.free"
            local cmd = shell.touch_command(file)
            assert.truthy(cmd:find(file, 0, true))
        end)

        it("returns New-Item command in powershell", function()
            load_shell_for(true, true)
            local cmd = shell.touch_command("/tmp/sentinel.free")
            assert.truthy(cmd:match("^New%-Item %-ItemType File %-Force "))
        end)

        it("includes the file path verbatim on powershell", function()
            load_shell_for(true, true)
            local file = "/home/user/.cache/nvim/code-runner-slot-1.free"
            local cmd = shell.touch_command(file)
            assert.truthy(cmd:find(file, 0, true))
        end)

        it("returns New-Item command in powershell", function()
            load_shell_for(true, false)
            local cmd = shell.touch_command("/tmp/sentinel.free")
            assert.truthy(cmd:match("^type nul >"))
        end)

        it("includes the file path verbatim on powershell", function()
            load_shell_for(true, false)
            local file = "/home/user/.cache/nvim/code-runner-slot-1.free"
            local cmd = shell.touch_command(file)
            assert.truthy(cmd:find(file, 0, true))
        end)
    end)

    describe("echo_command()", function()
        it("returns \"echo '<msg>'\" on Unix", function()
            load_shell_for(false, false)
            local cmd = shell.echo_command(">>> running")
            assert.equal("echo '>>> running'", cmd)
        end)

        it('returns \'Write-Host "<msg>"\' in powershell', function()
            load_shell_for(true, true)
            local cmd = shell.echo_command(">>> running")
            assert.equal("Write-Host '>>> running'", cmd)
        end)

        it("returns \"echo <msg>\" on windows (cmd)", function()
            load_shell_for(true, false)
            local cmd = shell.echo_command(">>> running")
            assert.equal('echo >>> running', cmd)
        end)
    end)
end)
