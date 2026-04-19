local M = {}

function M.check()
    vim.health.start("code-runner.nvim")

    -- Neovim version
    if vim.fn.has("nvim-0.10") == 1 then
        vim.health.ok("Neovim >= 0.10")
    else
        vim.health.error(
            "Neovim >= 0.10 is required",
            "Upgrade Neovim: https://github.com/neovim/neovim/releases"
        )
    end

    -- toggleterm: installed
    local tt_ok, _ = pcall(require, "toggleterm")
    if not tt_ok then
        vim.health.error(
            "toggleterm.nvim is not installed",
            "Add akinsho/toggleterm.nvim as a dependency: https://github.com/akinsho/toggleterm.nvim"
        )
        -- Nothing below can be verified without toggleterm, so stop here.
        return
    end
    vim.health.ok("toggleterm.nvim is installed")

    -- toggleterm: Terminal class accessible
    local tt_term_ok, tt_terminal = pcall(require, "toggleterm.terminal")
    if not tt_term_ok or not tt_terminal.Terminal then
        vim.health.error(
            "toggleterm.terminal.Terminal is not accessible",
            "Ensure toggleterm.nvim is up to date"
        )
    else
        vim.health.ok("toggleterm.terminal.Terminal is accessible")
    end

    -- toggleterm: setup() has been called
    local tt_cfg_ok, tt_config = pcall(require, "toggleterm.config")
    if tt_cfg_ok and tt_config and tt_config.get then
        vim.health.ok("toggleterm.nvim setup() has been called")
    else
        vim.health.warn(
            "Could not confirm toggleterm.nvim setup() has been called",
            "Ensure toggleterm.setup() is called before code-runner loads"
        )
    end

    -- code-runner: setup() has been called
    local cr_ok, config = pcall(require, "code-runner.config")
    if cr_ok and config.options ~= config.defaults then
        vim.health.ok("code-runner setup() has been called")
    else
        vim.health.info(
            "code-runner setup() has not been called — using default configuration"
        )
    end

    -- Python: interpreter available
    vim.health.start("code-runner.nvim — Python runner")

    local has_python3 = vim.fn.executable("python3") == 1
    local has_python  = vim.fn.executable("python") == 1

    if has_python3 then
        local version = vim.fn.system("python3 --version 2>&1"):gsub("\n", "")
        vim.health.ok("python3 found: " .. version)
    elseif has_python then
        local version = vim.fn.system("python --version 2>&1"):gsub("\n", "")
        vim.health.ok("python found: " .. version)
    else
        vim.health.warn(
            "No Python interpreter found on PATH",
            "Install Python or ensure it is on your PATH if you intend to run Python files"
        )
    end

    -- Virtual environment discovery
    local venv = os.getenv("VIRTUAL_ENV")
    if venv and venv ~= "" then
        vim.health.ok("$VIRTUAL_ENV is set: " .. venv)
    else
        vim.health.info("$VIRTUAL_ENV is not set — venv will be located by directory search")
    end
end

return M
