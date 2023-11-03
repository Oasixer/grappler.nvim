 <h1 align="center">
  grappler.nvim
</h1>

![youtube-video-gif](https://github.com/Oasixer/grappler.nvim/assets/24990515/0765b750-f971-4506-bdae-92c3e23b3e21)

<p align="center">A new and <i>crunchy</i> approach to medium-scale movements in vim by raycasting for whitespace boundaries.
Heavily inspired by grappling hooks in 2D platformers. Built and configured using <b>lua</b> 
</p>
  <!-- (see <a href="https://neovim.io/doc/user/lua-guide.html">lua guide</a>) -->
![demo-gif](https://kaelan.xyz/images/grappler.gif)
![demo-gif2](https://kaelan.xyz/images/grappler.mp4)

![youtube-video-gif](https://github.com/Oasixer/grappler.nvim/assets/24990515/0765b750-f971-4506-bdae-92c3e23b3e21)

<!--toc:start-->

- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Features](#features)

<!--toc:end-->

## Requirements

- Neovim 0.8+
- A patched font (see [nerd fonts](https://github.com/ryanoasis/nerd-fonts))

## Installation

Specify either the latest tag or a specific tag and bump them manually if you'd prefer to inspect changes before updating.
Otherwise, `"*"` will keep you up to date.

**Lua**

```lua
-- using packer.nvim
use {'oasixer/grappler.nvim', tag = "*"}

-- using lazy.nvim
{'oasixer/grappler.nvim', version = "*"}
```

**Vimscript**

```vim
Plug 'oasixer/grappler.nvim', { 'tag': '*' }
```

## Usage

See the docs for details `:h grappler.nvim`

You must use `termguicolors`, as the plugin reads the hex `gui` color values of various highlight groups.

## Configuration

This section outlines the customization options through the setup function of the module.

### Default config

```lua
-- No need to copy this inside `setup()`. Will be used automatically.
require("grappler").setup({
  -- Draw options
  draw = {
    tick_ms = 4, -- delay applied between each animation tick.
    delay = 15, -- delay after the hook reaches the target
    priority = 2, -- Symbol priority. higher = display on top of more symbols.

    chain_color = { -- chain = the line connecting to the grappling target
      fg = "#ffa500",
      bg = "NONE",
    },

    hook_color = { -- hook = the symbol drawn on the target char
      fg = "#ffa500",
      bg = "NONE",
    },
  },

  -- Directional grapple mappings. Use "" to disable.
  mappings = {
    up = "<Up>",
    right = "<Right>",
    down = "<Down>",
    left = "<Left>",
    up_right = "go",
    down_right = "gO",
    up_left = "gi",
    down_left = "gI",
  },

  -- Which characters to use for drawing. Default are from unicode block codes
  symbols = {
    chain = {
      up = "│",
      up_right = "╱",
      right = "─",
      down_right = "╲",
      down = "│",
      down_left = "╱",
      left = "─",
      up_left = "╲",
    },
    hook = "█",
  },

  max_col = 120, -- don't grapple too far right by accident.

  -- [disabled by default]: highlight the text around target
  highlight_target = {
    enable = false,

    bg = "#440040", -- highlight BG color
    fg = "#939993", -- highlight FG color
    -- if true, enable highlighting entire block
    highlight_entire_block = true,
    highlight_x_chars = 3, -- only respected if highlight_entire_block == false
    highlight_y_chars = 2, -- only respected if highlight_entire_block == false
  },
}
```

## Features

- Grapple to the edge of the next whitespace, or to the next non-whitespace if already in whitespace.
- Grapple in any of the 8 directions
- Repeat grapple motions with `N<Keybind>` where `N` is the number of times to repeat.

### Future plans

- Account for virtcol which currently cause minorly incorrect motions on wrapped lines
- Allow more flexible customization of the draw animation ie. pass in a user defined callback to decide draw/frame rates as a function of distance and state
