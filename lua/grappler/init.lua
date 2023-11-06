local utils = require("grappler.utils")
--
-- Module definition ==========================================================
local Grappler = {}
local H = {}

--- Module setup
---
---@param config table|nil Module config table. See |Grappler.config|.
---
---@usage `require('grappler').setup({})` (replace `{}` with your `config` table)
Grappler.setup = function(config)
  -- TODO: Remove after Neovim<=0.6 support is dropped
  if vim.fn.has("nvim-0.7") == 0 then
    vim.notify("(Neovim<0.7 is not supported by Grappler. Well I never tested it anyway)")
  end

  -- Export module
  _G.Grappler = Grappler

  -- Setup config
  config = H.setup_config(config)

  -- Apply config
  H.apply_config(config)

  vim.cmd(
    "highlight GrapplerSymbolChain guibg="
      .. config.draw.hook_color.bg
      .. " guifg="
      .. config.draw.chain_color.fg
      .. " gui=NONE"
  )
  vim.cmd(
    "highlight GrapplerSymbolHook guibg="
      .. config.draw.chain_color.bg
      .. " guifg="
      .. config.draw.hook_color.fg
      .. " gui=NONE"
  )
end

Grappler.config = {
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

-- Helper function to check if a character at a specific index is a non-space character
function H.is_idx_non_space(line_content, col)
  return not H.is_idx_blank(line_content, col)
end

-- function to highlight non-space characters around a target
function H.highlightNonSpaceCharactersSearchTarget(target, opts)
  -- opts should resemble:
  -- highlight_target = {
  --   enable = false,
  --   highlight_entire_block = true,
  --   highlight_x_chars = 3,
  --   highlight_x_chars = 2,
  --   highlight_bg_color = ''
  -- },
  if opts.enable == false then
    return
  end
  local extmark_opts = {
    hl_mode = "combine",
    priority = 3,
    right_gravity = false,
    virt_text_pos = "overlay",
  }

  local config = H.get_config()

  -- Get the current buffer
  local current_buf = vim.api.nvim_get_current_buf()

  -- Define the namespace for our highlights
  local ns_id = H.ns_id_nonspace

  -- Create a table to act as a queue for BFS
  local queue = { target }

  -- Initialize the set to store visited locations
  local visited = {}

  -- Function to mark a location as visited
  function visit(row, column)
    -- Generate a unique key for the pair
    local key = row .. ":" .. column

    -- Set the key in the table to mark it as visited
    visited[key] = true
  end

  -- Function to check if a location has been visited
  function isVisited(row, column)
    -- Generate the key for the pair
    local key = row .. ":" .. column

    -- Check if the key exists in the visited table
    return visited[key] == true
  end

  -- Get the total number of lines in the buffer
  local num_lines = vim.api.nvim_buf_line_count(current_buf)
  local n_visited = 0

  local box_rad_y = config.draw.highlight_target.highlight_y_chars
  local box_rad_x = config.draw.highlight_target.highlight_x_chars

  while #queue > 0 do
    n_visited = n_visited + 1

    local current = table.remove(queue, 1)
    -- Check if the current position has been visited
    -- if visited[current.line * num_lines + current.col] then
    if isVisited(current.line, current.col) then
      -- print("(visited)")
      goto continue
    end
    visit(current.line, current.col)

    if box_rad_x > 0 then
      if math.abs(current.line - target.line) > box_rad_y then
        goto continue
      end
      if math.abs(current.col - target.col) > box_rad_x then
        goto continue
      end
    end
    if current.line < 1 or current.line > num_lines or current.col < 0 then
      -- print("(current.line, current.col) < 1, or < 0: (" .. current.line .. "," .. current.col .. ")")
      goto continue
    end
    local line_content = vim.api.nvim_buf_get_lines(current_buf, current.line - 1, current.line, false)[1]
    -- print("line_content: " .. line_content)
    if line_content == nil then
      print("uhoh nil line_content on line " .. current.line)
    end
    if H.is_idx_blank(line_content, current.col) then
      -- print("found blank at " .. current.col .. "=" .. H.char_at(line_content, current.col))
      goto continue
    else
      -- print("found char at " .. current.col .. "=" .. H.char_at(line_content, current.col))
    end

    -- print("highlighting on l=" .. current.line .. " col@" .. current.col .. "=" .. H.char_at(line_content, current.col))
    extmark_opts.virt_text = { { H.char_at(line_content, current.col), "NonSpaceHighlight" } }
    extmark_opts.virt_text_win_col = current.col
    extmark_opts.hl_group = "NonSpaceHighlight"

    vim.api.nvim_buf_set_extmark(current_buf, ns_id, current.line - 1, 0, extmark_opts)
    if n_visited > 4000 then
      -- print(">200")
    else
      table.insert(queue, { line = current.line - 1, col = current.col })
      table.insert(queue, { line = current.line + 1, col = current.col })
      table.insert(queue, { line = current.line, col = current.col - 1 })
      table.insert(queue, { line = current.line, col = current.col + 1 })
    end

    ::continue::
  end
end

H.get_deltas = function(src, target, direct)
  local target_line, target_col = target.line, target.col
  local original_line, original_col = src.line, src.col
  local delta_line, delta_col = (target_line - original_line), (target_col - original_col)
  if direct[2] == 0 then
    delta_col = 0
    -- TODO: temp fix for virtcol nonsense
    -- specifically, i cant do virtcol({line,x}) when x is > the length of line `line` because it just returns 0,
    -- yet, when I have my cursor beyond the legnth of line `line` using virtualedit, virtcol(".") returns the correct virtual col.
    -- I just want to be able to do that, but for other lines than the current one. virtcol({line, "."}) doesn't seem to work either.
    -- ... the fact that this function even needs `direct` is nonsense haha...
    -- ... i mean literally i could technically fix this by setting the cursor to target and doing virtcol(".") then returning the cursor but thats ridiculous.
  elseif direct[2] == 1 and direct[1] == -1 then
    delta_col = delta_line
  elseif direct[2] == -1 and direct[1] == -1 then
    delta_col = -delta_line
  elseif direct[1] == 0 then
  end
  local n_chain_steps = math.max(math.abs(delta_col), math.abs(delta_line)) - 1
  local res = {
    delta_line = delta_line,
    delta_col = delta_col,
    n_chain_steps = n_chain_steps,
  }
  return res
end

H.disable_cursor_line_and_col = function()
  H.cursorline_opt = vim.api.nvim_get_option_value("cursorline", {})
  H.cursorcol_opt = vim.api.nvim_get_option_value("cursorcolumn", {})
  H.virtualedit_opt = vim.api.nvim_get_option_value("virtualedit", {})
  -- H.original_virtualedit = vim.wo.virtualedit
  vim.api.nvim_set_option_value("cursorline", false, { scope = "local" })
  vim.api.nvim_set_option_value("cursorcolumn", false, { scope = "local" })
  vim.api.nvim_set_option_value("virtualedit", "all", { scope = "local" })
end

H.reset_cursor_line_and_col = function()
  vim.api.nvim_set_option_value("cursorline", H.cursorline_opt, { scope = "local" })
  vim.api.nvim_set_option_value("cursorcolumn", H.cursorcol_opt, { scope = "local" })
  vim.api.nvim_set_option_value("virtualedit", H.virtualedit_opt, { scope = "local" })
end

Grappler.grapple = function(direct) -- grapple()
  H.final_cleanup = false
  if H.current.grapple_status == true or H.is_disabled() then
    return
  end
  H.current.grapple_status = true

  H.disable_cursor_line_and_col()

  -- temporarily disable
  -- H.current.draw_status = "drawing"
  local config = H.get_config()

  local tick_ms = config.draw.tick_ms

  -- temporary fix for timing differences: orthogonal movement being slower for unknown reasons
  -- ... obviously it would be ideal to not ignore the user's tick setting
  -- in half the cases... and instead ensure equal timing for each mode
  -- by actually measuring the previous tick time like a game engine
  -- to ensure timing does not vary with framerate/tickrate. TODO.
  if direct[1] == 0 then -- horizontal
    tick_ms = 1
  elseif direct[2] == 0 then -- vertical
    tick_ms = 5
  end

  local delay = config.draw.delay
  local buf_id = vim.api.nvim_get_current_buf()
  -- local delays = {}
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local col = vim.fn.virtcol(".") - 1

  -- local line_content = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1] -- [1] to grab the 1 and only line we requested
  local max_virt_col = vim.fn.virtcol("$")

  if direct[2] == -1 then -- left or left diagonal
    if col == 0 then
      H.current.grapple_status = false
      return
    end
  end
  if direct[1] == 0 and direct[2] == 1 then -- right
    local delta = max_virt_col - col
    if delta == 3 then
      --     / last word in line, cursor on X, grappling right
      -- aaXa
      --
      -- just move right one.
      --
      -- aaaX
      vim.api.nvim_feedkeys("l", "n", false)
      H.current.grapple_status = false
      return
    end
    if delta == 2 then
      --      / last word in line, cursor on X, grappling right
      -- aaaX
      --
      -- no point grappling right all the way to the edge
      -- of the screen, so just return early, do nothing.
      H.current.grapple_status = false
      return
    end
  end

  local res = H.ray_cast_for_grapple_target(line, col, direct)
  if not res.found_target then
    H.current.grapple_status = false
    return
  end
  H.highlightNonSpaceCharactersSearchTarget(res.target, config.highlight_target)

  local draw_opts = {
    event_id = H.current.event_id,
    type = "animation",
    delay = config.draw.delay,
    tick_ms = config.draw.tick_ms,
    priority = config.draw.priority,
  }

  -- todo use a sensible opts structure or something...								 chains, reel
  local draw_func_chain = H.make_draw_function(buf_id, draw_opts, direct, false, false)
  local draw_func_hook = H.make_draw_function(buf_id, draw_opts, direct, true, false)
  local draw_func_reel = H.make_draw_function(buf_id, draw_opts, direct, false, true)

  local res_ = H.get_deltas(res.src, res.target, direct)
  local n_chain_steps = res_.n_chain_steps

  local n_reel_steps = n_chain_steps + 1

  -- don't draw chain on cursor
  local og_line, og_col = line + direct[1], col + direct[2]
  local step, wait_time = 0, 0
  local reel_step = 0

  local extmark_ids = { chain = {}, hook = {} }
  extmark_ids.all = function()
    return utils.array_concat(extmark_ids.chain, extmark_ids.hook)
  end

  local draw_step = vim.schedule_wrap(function()
    local cur_chain_line = og_line + step * direct[1]
    local cur_chain_col = og_col + step * direct[2]
    local chain_extmark_id = draw_func_chain(cur_chain_line, cur_chain_col)
    if chain_extmark_id == false then
      -- print("failed to put chain extmark")
    else
      table.insert(extmark_ids["chain"], chain_extmark_id)
    end
    if step >= n_chain_steps - 1 then -- TODO code re-use here
      H.timer:stop()
      local final_offset = n_chain_steps
      local hook_extmark_id = draw_func_hook(og_line + final_offset * direct[1], og_col + final_offset * direct[2])
      if hook_extmark_id == false then
        print("failed to put hook extmark")
      else
        table.insert(extmark_ids["hook"], hook_extmark_id)
      end

      -- H.current.draw_status = "finished"
      vim.defer_fn(function()
        H.finished_callback()
      end, delay)
      return
    end

    step = step + 1
    wait_time = tick_ms --animation_func(step, n_steps)

    -- Repeat value of `timer` seems to be rounded down to milliseconds. This
    -- means that values less than 1 will lead to timer stop repeating. Instead
    -- call next step function directly.
    H.timer:set_repeat(wait_time)

    -- Usage of `again()` is needed to overcome the fact that it is called
    -- inside callback and to restart initial timer. Mainly in case of
    -- transition from 'non-repeating' timer to 'repeating', see
    -- https://docs.libuv.org/en/v1.x/timer.html#api
    H.timer:again()
  end)

  -- hijack this timer to get it working.
  local final_cleanup_delay = 3

  local draw_reel_step = vim.schedule_wrap(function()
    if H.final_cleanup == true then
      H.timer:stop()
      H.undraw()
      H.undraw_nonspace()
      H.reset_cursor_line_and_col()
      H.current.grapple_status = false
      H.final_cleanup = false -- reset in case this ever gets made global
      return
    end

    local all_extmarks = extmark_ids.all()

    local succ =
      draw_func_reel(og_line + direct[1] * reel_step, og_col + direct[2] * reel_step, all_extmarks[reel_step + 1])

    if reel_step >= n_reel_steps - 1 then -- TODO code re-use here
      H.final_cleanup = true
      H.timer:set_repeat(final_cleanup_delay)
      -- Stop the timer, and if it is repeating restart it using the
      -- repeat value as the timeout. If the timer has never been
      -- started before it raises EINVAL.
      H.timer:again()
    else
      reel_step = reel_step + 1
      wait_time = tick_ms --animation_func(step, n_steps)
      H.timer:set_repeat(wait_time)

      -- Stop the timer, and if it is repeating restart it using the
      -- repeat value as the timeout. If the timer has never been
      -- started before it raises EINVAL.
      H.timer:again()
    end
  end)

  local reel_callback = function()
    -- vim.wo.virtualedit = "all"

    -- Start non-repeating timer without callback execution. This shouldn't be
    -- `timer:start(0, 0, draw_step)` because it will execute `draw_step` on the
    -- next redraw (flickers on window scroll).
    H.timer:start(10000000, 0, draw_reel_step)

    -- Draw step zero (at origin) immediately
    draw_reel_step()
  end
  --
  --	 -- Start non-repeating timer without callback execution. This shouldn't be
  --	 -- `timer:start(0, 0, draw_step)` because it will execute `draw_step` on the
  --	 -- next redraw (flickers on window scroll).
  --	 --
  --	 --(timeout, repeat, callback)
  H.timer:start(10000000, 0, draw_step)
  --
  H.finished_callback = reel_callback

  -- Draw step zero (at origin) immediately
  draw_step()
end

-- Helper data ================================================================
-- Module default config
H.default_config = Grappler.config

-- Namespace for drawing most stuff
H.ns_id = vim.api.nvim_create_namespace("Grappler")
-- Namespace for drawing specifically the paragraph highlighting
H.ns_id_nonspace = vim.api.nvim_create_namespace("GrapplerNonSpace")

-- Timer for doing animation
H.timer = vim.uv.new_timer()

-- Table with current relevalnt data:
-- - `event_id` - counter for events.
-- - `scope` - latest drawn scope.
-- - `draw_status` - status of current drawing.
H.current = { event_id = 0, grapple_status = false }

-- Helper functionality =======================================================
-- Settings -------------------------------------------------------------------
H.setup_config = function(config)
  -- General idea: if some table elements are not present in user-supplied
  -- `config`, take them from default config
  vim.validate({ config = { config, "table", true } })
  config = vim.tbl_deep_extend("force", H.default_config, config or {})

  -- Validate per nesting level to produce correct error message
  vim.validate({
    draw = { config.draw, "table" },
    mappings = { config.mappings, "table" },
    symbols = { config.symbols, "table" },
    highlight_target = { config.highlight_target, "table" },
  })

  vim.validate({
    ["draw.tick_ms"] = { config.draw.tick_ms, "number" }, -- delay applied between each animation tick.
    ["draw.delay"] = { config.draw.delay, "number" }, -- delay after the hook reaches the target
    ["draw.priority"] = { config.draw.priority, "number" },

    ["mappings.right"] = { config.mappings.up_right, "string" },
    ["mappings.up_right"] = { config.mappings.up_right, "string" },
    ["mappings.up"] = { config.mappings.up, "string" },
    ["mappings.up_left"] = { config.mappings.up_left, "string" },
    ["mappings.left"] = { config.mappings.up_left, "string" },
    ["mappings.down_left"] = { config.mappings.down_left, "string" },
    ["mappings.down"] = { config.mappings.down, "string" },
    ["mappings.down_right"] = { config.mappings.down_right, "string" },

    -- Validate symbols
    ["symbols.chain.up"] = { config.symbols.chain.up, "string" },
    ["symbols.chain.up_right"] = { config.symbols.chain.up_right, "string" },
    ["symbols.chain.right"] = { config.symbols.chain.right, "string" },
    ["symbols.chain.down_right"] = { config.symbols.chain.down_right, "string" },
    ["symbols.chain.down"] = { config.symbols.chain.down, "string" },
    ["symbols.chain.down_left"] = { config.symbols.chain.down_left, "string" },
    ["symbols.chain.left"] = { config.symbols.chain.left, "string" },
    ["symbols.chain.up_left"] = { config.symbols.chain.up_left, "string" },
    ["symbols.hook"] = { config.symbols.hook, "string" },

    -- Validate max_col
    ["max_col"] = { config.max_col, "number" },

    -- Validate highlight_target
    ["highlight_target.enable"] = { config.highlight_target.enable, "boolean" },
    ["highlight_target.bg"] = { config.highlight_target.bg, "string" },
    ["highlight_target.fg"] = { config.highlight_target.fg, "string" },
    ["highlight_target.highlight_entire_block"] = { config.highlight_target.highlight_entire_block, "boolean" },
    ["highlight_target.highlight_x_chars"] = { config.highlight_target.highlight_x_chars, "number" },
    ["highlight_target.highlight_y_chars"] = { config.highlight_target.highlight_y_chars, "number" },
  })

  return config
end

H.apply_config = function(config)
  Grappler.config = config
  local maps = config.mappings

  H.map("n", maps.up_left, [[<Cmd>lua Grappler.grapple({-1, -1})<CR>]], { desc = "Grapple up-left" })
  H.map("n", maps.up_left, [[<Cmd>lua Grappler.grapple({-1, -1})<CR>]], { desc = "Grapple up-left" })
  H.map("n", maps.up_right, [[<Cmd>lua Grappler.grapple({-1, 1})<CR>]], { desc = "Grapple up-right" })
  H.map("n", maps.down_left, [[<Cmd>lua Grappler.grapple({1, -1})<CR>]], { desc = "Grapple down-left" })
  H.map("n", maps.down_right, [[<Cmd>lua Grappler.grapple({1, 1})<CR>]], { desc = "Grapple down-right" })
  H.map("n", maps.up, [[<Cmd>lua Grappler.grapple({-1, 0})<CR>]], { desc = "Grapple up" })
  H.map("n", maps.down, [[<Cmd>lua Grappler.grapple({1, 0})<CR>]], { desc = "Grapple down" })
  H.map("n", maps.left, [[<Cmd>lua Grappler.grapple({0, -1})<CR>]], { desc = "Grapple left" })
  H.map("n", maps.right, [[<Cmd>lua Grappler.grapple({0, 1})<CR>]], { desc = "Grapple right" })
end

H.is_disabled = function()
  return vim.g.grappler_disable == true or vim.b.grappler_disable == true
end

H.get_config = function(config)
  return vim.tbl_deep_extend("force", Grappler.config, vim.b.grappler_config or {}, config or {})
end

-- get char at 0-indexed idx
H.char_at = function(str, idx)
  return str:sub(idx + 1, idx + 1) -- account for 1-indexing bleh
end

-- returns whether a 0-indexed `col` index in `line_content` is "blank"
-- where "blank" means either nonspace or surrounded on both sides
-- by nonspace characters.
H.is_idx_blank = function(line_content, col)
  local char = H.char_at(line_content, col)
  if char == "" then
    return true
  end
  local char_left = H.char_at(line_content, col - 1)
  local char_right = H.char_at(line_content, col + 1)
  -- console.log("char_right")
  local match = char:match("%s")
  local found_char_left = not char_left:match("%s")
  local found_char_right = not char_right:match("%s")
  if match == nil then
    return false
  end
  if found_char_left and found_char_right then
    return false
  end
  return true
end

--
-- for grappling hook based movement, cast a ray in one of 8 diagonal directions
--                                      [permutations of line=<1|0|-1>,col=<1|0|-1>,]]
-- Params:
--   original_line(int): 0-indexed line from which the grappling hook was launched,
--   original_col(int): 0-indexed col from which the grappling hook was launched
--
-- Returns:
--   table: {
--     src={line,col},
--     target=<{line,col} | nil>,
--     found_target=bool
--   }
--    [cursor]
--       |   ____[target]
-- eg.   V  V
--  Lorem   Ipsum [before keypress]
--  Lorem█--psum [after]
--
-- in this example, the cursor was 3 cols from the target
H.ray_cast_for_grapple_target = function(original_line, original_col, direct)
  local config = H.get_config()
  local target_line, target_col = original_line, original_col
  -- ideally if we dont find a target we won't grapple at all... but this seems like a reasonable default.
  local max_col = math.min(vim.fn.winwidth(0) - 7, config.max_col) -- account for the left gutter 7 chars wide
  local max_line = vim.fn.line("$")

  local cur_line = original_line + direct[1]
  local cur_col = original_col + direct[2]

  local original_line_content = vim.api.nvim_buf_get_lines(0, original_line - 1, original_line, false)[1] -- [1] to grab the 1 and only line we requested
  local found_whitespace_yet = H.is_idx_blank(original_line_content, original_col)

  if cur_line > max_line then
    return {
      found_target = false,
      src = { line = original_line, col = original_col },
    }
  end
  local not_done = true
  local step = 0
  while not_done do
    if cur_line < 1 then
      target_line = 1 -- 1 indexed ughhh
      target_col = cur_col
      not_done = false
    elseif cur_line > max_line then
      target_line = max_line
      target_col = cur_col
      not_done = false
    elseif cur_col < 0 then -- 0 indexed WTF why are they different?
      target_col = 0
      target_line = cur_line -- TODO break
      not_done = false
    elseif cur_col >= max_col then
      target_col = max_col
      target_line = cur_line -- TODO break
      not_done = false
    end

    if not_done == true then
      local line_content = vim.api.nvim_buf_get_lines(0, cur_line - 1, cur_line, false)[1] -- [1] to grab the 1 and only line we requested
      local too_short = #line_content <= cur_col
      local found_char = not too_short
      if not too_short then -- skip some work if the line is too short to find a char anyway
        found_char = not H.is_idx_blank(line_content, cur_col)
        -- if not found_char and cur_col > 1 then
        --   local found_char_left = not H.is_idx_blank(line_content, cur_col - 1)
        --   local found_char_right = not H.is_idx_blank(line_content, cur_col + 1)
        --   if found_char_left and found_char_right then
        --     found_char = true
        --   end
        -- end
      end

      -- if haven't found char, then we are on whitespace,
      if not found_char then
        -- we either just launched from the line below (and it's step 0 right now)
        -- or we have been grappling thru a solid block of text (and step > 0)
        if not found_whitespace_yet and step > 2 then
          target_line, target_col = cur_line - direct[1], cur_col - direct[2]
          not_done = false
        else
          found_whitespace_yet = true
        end
      elseif found_whitespace_yet and found_char then
        -- want to avoid 1-distance grapples inside of a block of text eg.
        --	 eg. in the example below, if we grapple up-right  from the cursor, do we want to land on
        -- X, Y, or Z? Im gonna say never X and Y by default, with Z (pass through edge) being an option later on.
        --
        -- cccc cccc Z---
        --
        -- bbbb --Y- bbbb
        -- aaaa -X-- aaaa
        -- blah █lah blah
        --
        -- a "chain step" is an iteration of drawing chain in the grappling hook ie.
        --------------------
        --  Lorem   Ipsum [before keypress]
        --  Lorem█--psum [after]
        --
        -- in this example, the cursor was 3 cols from the target, and so there are 2 chains in between
        -- so n_chain_steps would be 2, hence the verbose name
        --
        -- local delta_col, delta_line = (cur_line - original_line), (cur_col - original_col)
        --

        local res_ = H.get_deltas(
          { line = original_line, col = original_col },
          { line = cur_line, col = cur_col },
          direct
        )
        -- local delta_col = res_.delta_col
        -- -- - vim.fn.virtcol({ res.src.line, res.src.col })
        -- local delta_line = res_.delta_line
        local n_chain_steps = res_.n_chain_steps
        -- vim.notify("n_chain_steps: " .. n_chain_steps)
        if n_chain_steps > 0 then
          target_col = cur_col
          target_line = cur_line
          not_done = false
        else
          -- print("skipping n_chain_steps == 0 (so 1 dist. away from target) grapple")
        end
      end
    end
    step = step + 1
    cur_line = cur_line + direct[1]
    cur_col = cur_col + direct[2]
  end
  return {
    found_target = true,
    target = { line = target_line, col = target_col },
    src = { line = original_line, col = original_col },
  }
end

-- undraw the nonspace highlihgted block.
H.undraw_nonspace = function()
  pcall(vim.api.nvim_buf_clear_namespace, H.current.buf_id or 0, H.ns_id_nonspace, 0, -1)
end

-- undraw_chains / undraw / cleanup / delelete extmarks / clear ns
H.undraw = function()
  local buf_id = H.current.buf_id

  -- Don't operate outside of current event if able to verify
  -- if opts.event_id and opts.event_id ~= H.current.event_id then
  --	 return
  -- end

  pcall(vim.api.nvim_buf_clear_namespace, buf_id or 0, H.ns_id, 0, -1)

  -- vim.defer_fn doesnt work here, probably because this function
  -- is already under a timer...
  -- vim.defer_fn(function()
  --   -- pcall(vim.api.nvim_buf_clear_namespace, buf_id or 0, H.ns_id_nonspace, 0, -1)
  --   end, 2000)
  H.current.draw_status = "none"
  H.current.grapple_status = false
  H.current.scope = {}
end

H.make_draw_function = function(buf_id, opts, direct, hook, reel)
  local current_event_id = opts.event_id
  local hl_group_chain = "GrapplerSymbolChain"
  local hl_group_hook = "GrapplerSymbolHook"
  local config = H.get_config()

  local virt_text
  if hook == true then
    virt_text = { { config.symbols.hook, hl_group_hook } }
  else
    local chain_symbols = config.symbols.chain
    if direct[2] == 1 then
      if direct[1] == -1 then
        virt_text = { { chain_symbols.up_right, hl_group_chain } }
      elseif direct[1] == 0 then
        virt_text = { { chain_symbols.right, hl_group_chain } }
      else
        virt_text = { { chain_symbols.down_right, hl_group_chain } }
      end
    elseif direct[2] == 0 then
      virt_text = { { chain_symbols.up, hl_group_chain } }
    else -- col negative
      if direct[1] == 1 then
        virt_text = { { chain_symbols.down_left, hl_group_chain } }
      elseif direct[1] == -1 then
        virt_text = { { chain_symbols.up_left, hl_group_chain } }
      else
        virt_text = { { chain_symbols.left, hl_group_chain } }
      end
    end
  end

  -- generate draw callback function
  return function(line, col, extmark_id)
    local extmark_opts = {
      hl_mode = "combine",
      priority = opts.priority,
      right_gravity = false,
      virt_text = virt_text,
      virt_text_win_col = col,
      virt_text_pos = "overlay",
    }
    if H.current.event_id ~= current_event_id and current_event_id ~= nil then
      return false
    end

    if reel then
      local del_extmark_success = pcall(vim.api.nvim_buf_del_extmark, buf_id, H.ns_id, extmark_id)
      if del_extmark_success then
        if col < 0 then
          -- vim.notify("why r u trying to crash with setting cursor to col = " .. col)
          col = 0
        elseif line > vim.fn.line("$") then
          -- vim.notify("why r u trying to crash with setting line=" .. line .. "> buffer length")
          line = vim.fn.line("$")
        else
          local set_cursor_success = pcall(vim.api.nvim_win_set_cursor, 0, { line, col })

          if set_cursor_success then
            -- TODO: for some reason nvim_win_set_cursor() has different x offset on lines with and without content
            -- and its affected by tabs, because a tab is a single character (a single column)
            -- not sure if its affected by tabs outside of virualedit tho
            local stupid_virtual_screen_offset = vim.fn.virtcol(".") - col - 1
            if stupid_virtual_screen_offset ~= 0 then
              vim.api.nvim_win_set_cursor(0, { line, col - stupid_virtual_screen_offset })
            end
            return true
          else
            -- vim.notify("failed to set cursor to (line=" .. line .. "," .. col .. ")")
          end
        end
      end
      -- idk why this tends to fail for i but TODO: fix later.
      -- btw it wasnt from tring to delete the same extmark id multiple times so idk what caused it...
      return false
    else
      -- return pcall(vim.api.nvim_buf_set_extmark, buf_id, H.ns_id, line - 1, 0, extmark_opts)
      local succ, id = pcall(vim.api.nvim_buf_set_extmark, buf_id, H.ns_id, line - 1, 0, extmark_opts)
      if succ then
        return id
      else
        print("failed to set extmark")
        return false
      end
    end
  end
end

H.map = function(mode, key, rhs, opts)
  if key == "" then
    return
  end

  opts = vim.tbl_deep_extend("force", { noremap = true, silent = true }, opts or {})

  -- Use mapping description only in Neovim>=0.7
  if vim.fn.has("nvim-0.7") == 0 then
    opts.desc = nil
  end

  vim.api.nvim_set_keymap(mode, key, rhs, opts)
end

-- H.exit_visual_mode = function()
--   local ctrl_v = vim.api.nvim_replace_termcodes("<C-v>", true, true, true)
--   local cur_mode = vim.fn.mode()
--   if cur_mode == "v" or cur_mode == "V" or cur_mode == ctrl_v then
--     vim.cmd("normal! " .. cur_mode)
--   end
-- end

return Grappler
