# code-runner.nvim

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
    requries = { "akinsho/toggleterm.nvim" },
    config = function()
        require("code-runner").setup(),
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
local defaults = {
  max_slots = 3, -- The maximum number of terminals that can run in parallel
  slot_id_offset = 100, -- The offset to apply to toggleterm's terminal id to avoid clashes
  busy_behaviour = {
    @type "ask" | "interrupt" | "cancel" | "new"
    behaviour = "ask", -- What to do if no terminals are available
    interrupt_delay_ms = 100, -- How long to wait after interrupting a terminal before sending the next command
  },
  -- Settings specific to a given language
  runners = {
    python = {
      venv_names = { ".venv", "venv", ".env", "env" }, -- Virtual environment names to look for to find an interpreter
    },
  },
}
```

</details>

## Usage

### API

The following functions can be used in your keybindings:

```lua
--Run the current file
--Optionally forcing the creation of a new terminal
---@param new_terminal? boolean
require("code-runner").run_current_file(new_terminal)

--Run a file whose path is stored in a register
--Optionally forcing the creation of a new terminal
--If no register is specified, a user selects from valid options
---@param opts? {register?: string, new_terminal?: boolean}
require("code-runner").run_file_from_register(opts)

--Rerun the last command
--Optionally forcing the creation of a new terminal
---@param new_terminal? boolean
require("code-runner").rerun_last_command(new_terminal)

--Save the current file's path into a register
--If a register is not specified, user can input
---@param register? string
require("code-runner").save_current_file_path_to_register(new_terminal)

--Toggle a terminal's visibility
--If no terminal id is specified, user will be asked for one
---@param slot? integer
require("code-runner").toggle_terminal(slot)

--Toggle all terminals
--If any are open all will be closed. If all are closed, all will be opened.
require("code-runner").toggle_all_terminals()

--Close a terminal, interrupting anything that is running
--If no terminal id is specified, user will be asked for one
---@param slot? integer
require("code-runner").close_terminal(slot)

--Close all terminals, interrupting anything running
require("code-runner").close_all_terminals()
```
