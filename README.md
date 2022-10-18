<h1 align='center'>toggle_jaq.nvim</h1>
Just another pluging that allows to quickly run commands and show their results. This time in a togglable terminal window.

## Requirements

- Neovim >= 0.8.0

## Installation

- With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use { 'rareitems/toggle_jaq.nvim' }
```

## Default Configuration

```lua
{
  direction = "vertical",
  hide_numbers = true,
  size = 50,
  filetypes = {
    lua = { cmd = "lua %" },
    sml = { cmd = "rlwrap sml %", filetype = "sml" },
    javascript = { cmd = "node %" },
    typescript = { cmd = "ts-node %" },
  },
  create_commands = true,
  auto_resize = false,
  dynamic_size = nil,
  highlight_background = nil,
}
```
See more details under Config section in [help file](doc/toggle_jaq.txt).

## Usage

See details under Usage section in [help file](doc/toggle_jaq.txt).
