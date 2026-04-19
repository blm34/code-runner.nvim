# code-runner.nvim

<p align="center">
  <a href="https://github.com/blm34/code-runner.nvim/actions/workflows/test.yml">
    <img src="https://github.com/blm34/code-runner.nvim/actions/workflows/test.yml/badge.svg?branch=main" alt="Tests" />
  </a>
  <a href="https://github.com/blm34/code-runner.nvim/releases/latest">
    <img src="https://img.shields.io/github/v/release/blm34/code-runner.nvim" alt="Release" />
  </a>
  <a href="./LICENSE">
    <img src="https://img.shields.io/github/license/blm34/code-runner.nvim" alt="License" />
  </a>
  <img src="https://img.shields.io/github/stars/blm34/code-runner.nvim?style=social" alt="Stars" />
  <img src="https://img.shields.io/badge/Neovim-0.10%2B-blue" alt="Neovim" />
</p>

Run code files from within Neovim in an embedded terminal.

## Features

- Run the current file
- Save files to registers and run them from anywhere
- Re-run the last command from anywhere
- Automatic filetype detection
- Run multiple files in parallel
- Intelligent, customisable terminal reuse
- Toggle, interrupt, and close individual terminals or all at once

## Supported Languages

- Python

## Requirements

- Neovim ≥ 0.10
- [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim)

## Installation

<details>
    <summary><a href="https://github.com/folke/lazy.nvim"><b>lazy.nvim</b></a></summary>

```lua
{
    "blm34/code-runner.nvim",
    dependencies = { "akinsho/toggleterm.nvim" },
    opts = {},  -- calls setup() with default options
}
```

Pass a table to `opts` (or call `require("code-runner").setup({...})`) to
customise behaviour - see [Configuration](#configuration) below.

</details>

<details>
    <summary><a href="https://github.com/wbthomason/packer.nvim"><b>packer.nvim</b></a></summary>

```lua
use {
    "blm34/code-runner.nvim",
    requires = { "akinsho/toggleterm.nvim" },
    config = function()
        require("code-runner").setup()
    end,
}
```

Pass a table to `setup()` to customise behaviour - see [Configuration](#configuration) below.

</details>

## Configuration

A table can be passed to `require("code-runner").setup({...})` to customise the
plugin. Please refer to the default settings below.

<details>
    <summary>Default Settings</summary>

```lua
require("code-runner").setup({
    max_slots          = 3,     -- The maximum number of terminals that can run in parallel
    slot_id_offset     = 100,   -- The offset to apply to toggleterm's terminal ID to avoid clashes
    @type "ask" | "interrupt" | "cancel" | "new"
    busy_behaviour     = "ask", -- What to do if no terminals are available
    interrupt_delay_ms = 100,   -- How long to wait after interrupting a terminal before sending the next command
    -- Settings specific to a given language
    runners = {
        python = {
            venv_names = { ".venv", "venv", ".env", "env" }, -- Virtual environment names to look for to find an interpreter
        },
    },
})
```

</details>

## Usage

### Commands

A single `:CodeRunner` command covers all functionality. Subcommand names,
register letters, and slot numbers all tab-complete.

| Command | Description |
|---|---|
| `:CodeRunner` | Run the current file |
| `:CodeRunner!` | Run the current file in a new terminal |
| `:CodeRunner FromReg [x]` | Run the file in register `x` (picker if omitted) |
| `:CodeRunner! FromReg [x]` | Run the file in register `x` in a new terminal |
| `:CodeRunner SaveReg [x]` | Save the current file path to register `x` (prompts if omitted) |
| `:CodeRunner Last` | Re-run the last command |
| `:CodeRunner! Last` | Re-run the last command in a new terminal |
| `:CodeRunner Toggle [slot]` | Toggle all terminals, or a specific slot |
| `:CodeRunner Close [slot]` | Close all terminals, or a specific slot |

### API

The following functions can be used in keybindings:

```lua
-- Run the current file.
-- Optionally force a new terminal.
---@param new_terminal? boolean
require("code-runner").run_current_file(new_terminal)

-- Run a file whose path is stored in a register.
-- Optionally force a new terminal.
-- If no register is specified, a picker lists valid options.
---@param opts? {register?: string, new_terminal?: boolean}
require("code-runner").run_file_from_register(opts)

-- Re-run the last command.
-- Optionally force a new terminal.
---@param new_terminal? boolean
require("code-runner").rerun_last_command(new_terminal)

-- Save the current file's path to a register.
-- If no register is specified, the user is prompted.
---@param register? string
require("code-runner").save_current_file_path_to_register(register)

-- Toggle a terminal's visibility.
-- If no slot is specified, the user is asked for one.
---@param slot? integer
require("code-runner").toggle_terminal(slot)

-- Toggle all terminals.
-- Closes all if any are open, opens all if all are closed.
require("code-runner").toggle_all_terminals()

-- Close a terminal, interrupting anything running in it.
-- If no slot is specified, the user is asked for one.
---@param slot? integer
require("code-runner").close_terminal(slot)

-- Close all terminals, interrupting anything running.
require("code-runner").close_all_terminals()
```

For full documentation run `:h code-runner` inside Neovim.
