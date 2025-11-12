# cme.nvim

**C**ompilation **M**ode **E**xtern.

Crude implementation of Emacs' Compilation Mode.

## Installation

Using Neovim's built-in package manager:

```lua
vim.pack.add({
    {
        src = "https://github.com/yilisharcs/cme.nvim",
    },
    {
        src = "https://github.com/akinsho/toggleterm.nvim",
    },
})
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "yilisharcs/cme.nvim",
    specs = {
        {
            "https://github.com/nvim-lualine/lualine.nvim",
            optional = true,
            -- Fixes the small delay on `on_exit` updates
            opts = { options = { refresh = { statusline = 16 } } },
        },
    },
}
```

## Configuration

Below are the available options and their default values:

```lua
vim.g.cme = {
    shell = vim.o.shell
}
```

## Usage

cme.nvim provides a `:Compile` command that runs tasks in a terminal and
loads their output into the quickfix list. Arguments are passed to a bash
script which tracks the command's start time, end time, and duration. If
`:Compile` is called with no arguments, it executes the last known task.
If called with `:Compile!`, it won't automatically open the quickfix
window on exit.

> [!WARNING]
>
> I'm told that my colorizer code isn't Windows-compatible.

## See also

- compile-mode.nvim: <https://github.com/ej-shafran/compile-mode.nvim/>
- vim-dispatch: <https://github.com/tpope/vim-dispatch>

## License

Copyright (C) 2025 yilisharcs <yilisharcs@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
