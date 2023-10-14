--
--
-- Module definition ==========================================================
local Grappler = {}
local H = {}

function array_concat(...)
  local t = {}
  for n = 1, select("#", ...) do
    local arg = select(n, ...)
    if type(arg) == "table" then
      for _, v in ipairs(arg) do
        t[#t + 1] = v
      end
    else
      t[#t + 1] = arg
    end
  end
  return t
end

function serialize_table(val, name, skipnewlines, depth)
  skipnewlines = skipnewlines or false
  depth = depth or 0

  local tmp = string.rep(" ", depth)

  if name then
    tmp = tmp .. name .. " = "
  end

  if type(val) == "table" then
    tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

    for k, v in pairs(val) do
      tmp = tmp .. serialize_table(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
    end

    tmp = tmp .. string.rep(" ", depth) .. "}"
  elseif type(val) == "number" then
    tmp = tmp .. tostring(val)
  elseif type(val) == "string" then
    tmp = tmp .. string.format("%q", val)
  elseif type(val) == "boolean" then
    tmp = tmp .. (val and "true" or "false")
  else
    tmp = tmp .. '"[inserializeable datatype:' .. type(val) .. ']"'
  end

  return tmp
end

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
  print("setup config")

  -- Apply config
  H.apply_config(config)

  -- Module behavior
  -- vim.api.nvim_exec(
  --	 [[augroup Grappler
  --				au!
  --				au CursorMoved,CursorMovedI													* lua Grappler.auto_draw({ lazy = true })
  --				au TextChanged,TextChangedI,TextChangedP,WinScrolled * lua Grappler.auto_draw()
  --			augroup END]],
  --	 false
  -- )

  -- if vim.fn.exists("##ModeChanged") == 1 then
  --	 vim.api.nvim_exec(
  --		 -- Call `auto_draw` on mode change to respect `miniindentscope_disable`
  --		 [[augroup Grappler
  --					au ModeChanged *:* lua Grappler.auto_draw({ lazy = true })
  --				augroup END]],
  --		 false
  --	 )
  -- end

  -- Create highlighting
  vim.api.nvim_exec(
    [[hi default link GrapplerSymbolChain Delimiter
			hi default link GrapplerSymbolOff GrapplerSymbol]],
    false
  )
end

Grappler.config = {
  -- Draw options
  draw = {
    tick_ms = 20,
    -- Symbol priority. Increase to display on top of more symbols.
    priority = 2,
  },

  -- Module mappings. Use `''` (empty string) to disable one.
  mappings = {
    -- Textobjects
    -- object_scope = "ii",
    -- object_scope_with_border = "ai",

    -- Motions (jump to respective border line; if not present - body line)
    left = "sh",
    right = "sl",
    up = "sk",
    down = "sj",
    up_right = "so",
    up_left = "si",
    down_left = "sI",
    down_right = "sO",

    toggle_grapple_mode = "<A-g>",
  },

  -- Options which control scope computation
  options = {},

  -- Which character to use for drawing
  -- symbol = "╎",
  -- symbols = "/D",
}

-- Helper function to check if a character at a specific index is blank
-- Helper function to check if a character at a specific index is a non-space character
function H.is_idx_non_space(line_content, col)
  return not H.is_idx_blank(line_content, col)
end

-- function to highlight non-space characters around a target
function H.highlightNonSpaceCharactersSearchTarget(target)
  local extmark_opts = {
    hl_mode = "combine",
    priority = 3,
    right_gravity = false,
    virt_text_pos = "overlay",
  }

  -- Get the current buffer
  local current_buf = vim.api.nvim_get_current_buf()

  -- Define the namespace for our highlights
  local ns_id = H.ns_id

  -- Create a table to act as a queue for BFS
  local queue = { target }
  local visited = {}

  -- Get the total number of lines in the buffer
  local num_lines = vim.api.nvim_buf_line_count(current_buf)

  while #queue > 0 do
    local current = table.remove(queue, 1)
    print("---------")
    print("current=" .. serialize_table(current))

    -- Check if the current position has been visited
    if visited[current.line * num_lines + current.col] then
      goto continue
    end

    visited[current.line * num_lines + current.col] = true

    local line_content = vim.api.nvim_buf_get_lines(current_buf, current.line - 1, current.line, false)[1]

    print("checking everywhere")
    print("line_content: " .. line_content)
    -- Check left
    for col = current.col - 1, 0, -1 do
      print("checking left, l=" .. current.line .. ",col=" .. col)
      if H.is_idx_blank(line_content, col) then
        print("found blank left at " .. H.char_at(line_content, col))
        break
      end

      print("highlighting on current.line=" .. current.line .. "," .. H.char_at(line_content, col))
      extmark_opts.virt_text = { { H.char_at(line_content, col), "NonSpaceHighlight" } }
      extmark_opts.virt_text_win_col = col
      extmark_opts.hl_group = "NonSpaceHighlight"
      vim.api.nvim_buf_set_extmark(current_buf, ns_id, current.line - 1, 0, extmark_opts)
    end

    -- Check right
    for col = current.col + 1, #line_content do
      print("checking right, l=" .. current.line .. ",col=" .. col)
      if H.is_idx_blank(line_content, col) then
        print("found blank right at " .. col .. "=" .. H.char_at(line_content, col))
        break
      end

      extmark_opts.virt_text = { { H.char_at(line_content, col), "NonSpaceHighlight" } }
      extmark_opts.virt_text_win_col = col
      extmark_opts.hl_group = "NonSpaceHighlight"
      vim.api.nvim_buf_set_extmark(current_buf, ns_id, current.line - 1, 0, extmark_opts)
    end

    -- Check up
    if current.line > 1 then
      print("checking up, l=" .. current.line .. ",col=" .. current.col)
      local prev_line_content = vim.api.nvim_buf_get_lines(current_buf, current.line - 2, current.line - 1, false)[1]
      print("prev_line_content: " .. prev_line_content)
      if H.is_idx_blank(prev_line_content, current.col) then
        print("found blank up at " .. current.col .. "=" .. H.char_at(line_content, current.col))
      else
        print("up wasn't blank at idx .. " .. current.col .. ", char=" .. H.char_at(prev_line_content, current.col))
        table.insert(queue, { line = current.line - 1, col = current.col })
      end
    end

    -- Check down
    if current.line < num_lines - 1 then
      print("checking down, l=" .. current.line .. ",col=" .. current.col)
      local next_line_content = vim.api.nvim_buf_get_lines(current_buf, current.line, current.line + 1, false)[1]
      print("next_line_content: " .. next_line_content)
      if H.is_idx_blank(next_line_content, current.col) then
        print("found blank down at " .. current.col .. "=" .. H.char_at(line_content, current.col))
      else
        print("down wasn't blank at idx .. " .. current.col .. ", char=" .. H.char_at(next_line_content, current.col))
        table.insert(queue, { line = current.line + 1, col = current.col })
      end
    end

    ::continue::
  end
end

-- function to highlight non-space characters in each line
function H.highlightNonSpaceCharacters()
  -- vim.cmd([[highlight GrapplerSymbolChain guibg=#660040 guifg=#939993]])

  local extmark_opts = {
    hl_mode = "combine", -- Replace existing text color
    priority = 2,
    right_gravity = false,
    virt_text = { { " ", "NonSpaceHighlight" } },
    virt_text_win_col = -1, -- TEMP (replaced)
    virt_text_pos = "overlay",
  }
  -- vim.notify("hi")
  -- Get the current buffer
  local current_buf = vim.api.nvim_get_current_buf()

  -- Get the total number of lines in the buffer
  local num_lines = vim.api.nvim_buf_line_count(current_buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_line, cursor_col = cursor[1], cursor[2]

  -- Define the namespace for our highlights
  -- local ns_id = vim.api.nvim_create_namespace("highlight_non_space")
  local ns_id = H.ns_id

  -- Iterate through each line
  for line_num = 0, num_lines - 1 do
    -- Get the content of the current line
    local line_content = vim.api.nvim_buf_get_lines(current_buf, line_num, line_num + 1, false)[1]
    if line_content == nil then
      print("couldn't get " .. line_num)
    end

    for col = 0, #line_content do
      local found_char = not H.is_idx_blank(line_content, col)
      if found_char then
        -- Highlight non-space characters with a custom highlight group
        -- extmark_opts.
        local char_at = H.char_at(line_content, col)
        extmark_opts.virt_text = { { char_at, "NonSpaceHighlight" } }
        extmark_opts.virt_text_win_col = col -- 0 indexed col <->1 indexed fucking lua string
        extmark_opts.hl_group = "NonSpaceHighlight" -- Change this to your desired highlight group
        -- Create an extmark for the non-space character
        -- vim.api.nvim_buf_set_extmark(current_buf, ns_id, line_num, col, extmark_opts)
        vim.api.nvim_buf_set_extmark(current_buf, ns_id, line_num, 0, extmark_opts)
      end
    end
  end
end

Grappler.toggle_grapple_mode = function() -- grapple()
end

Grappler.clear_symbols = function() -- grapple()
end

H.get_deltas = function(src, target, direct)
  --   "get_deltas. src: "
  --     .. serialize_table(src)
  --     .. " target: "
  --     .. serialize_table(target)
  --     .. "direct: "
  --     .. serialize_table(direct)
  -- )
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

Grappler.grapple = function(direct) -- grapple()
  vim.cmd([[highlight NonSpaceHighlight guibg=#440040 guifg=#939993 gui=NONE]])
  vim.cmd([[highlight GrapplerSymbolChain guibg=#000000 guifg=#FFFFFF gui=NONE]])
  vim.cmd([[highlight GrapplerSymbolHook guibg=#440040 guifg=#AA7700]])

  if H.current.grapple_status == true then
    -- if H.current.draw_status == "drawing" then
    return
  end
  -- H.highlightNonSpaceCharacters()
  H.current.grapple_status = true
  -- H.current.draw_status = "drawing"
  local config = H.get_config()
  local tick_ms = config.draw.tick_ms
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
  -- local line, col = cursor[1], cursor[2]
  local res = H.ray_cast_for_grapple_target(line, col, direct)
  if not res.found_target then
    print("no target found")
    H.current.grapple_status = false
    return
  end
  H.highlightNonSpaceCharactersSearchTarget(res.target)
  -- end

  -- Grappler.grapple2 = function(direct) -- grapple()
  local draw_opts = {
    event_id = H.current.event_id,
    type = "animation",
    delay = config.draw.delay,
    tick_ms = config.draw.tick_ms,
    priority = config.draw.priority,
  }

  -- todo use a sensible opts structure or something...								 chains, reel
  local draw_func_chain = H.make_draw_function2(buf_id, draw_opts, direct, false, false)
  local draw_func_hook = H.make_draw_function2(buf_id, draw_opts, direct, true, false)
  local draw_func_reel = H.make_draw_function2(buf_id, draw_opts, direct, false, true)

  -- H.normalize_animation_opts()
  -- local animation_func = config.draw.animation --Grappler.gen_animation.linear2(100)
  -- local delta_col = vim.fn.virtcol({ res.target.line, res.target.col }) - vim.fn.virtcol({ res.src.line, res.src.col })
  -- local tmp_delta1 = vim.fn.virtcol({ res.target.line, res.target.col })
  -- local tmp_delta2 = vim.fn.virtcol({ res.src.line, res.src.col })

  local res_ = H.get_deltas(res.src, res.target, direct)
  local n_chain_steps = res_.n_chain_steps

  -- Grappler.grapple_ = function(direct)
  local n_reel_steps = n_chain_steps + 1 -- TODO: resolve this

  -- don't draw chain on cursor
  local og_line, og_col = line + direct[1], col + direct[2]
  local step, wait_time = 0, 0
  local reel_step = 0

  local extmark_ids = { chain = {}, hook = {} }
  extmark_ids.all = function()
    return array_concat(extmark_ids.chain, extmark_ids.hook)
  end

  local draw_step = vim.schedule_wrap(function()
    local cur_chain_line = og_line + step * direct[1]
    local cur_chain_col = og_col + step * direct[2]
    local chain_extmark_id = draw_func_chain(cur_chain_line, cur_chain_col)
    if chain_extmark_id == false then
      print("failed to put chain extmark")
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

  local draw_reel_step = vim.schedule_wrap(function()
    local all_extmarks = extmark_ids.all()
    local succ =
      draw_func_reel(og_line + direct[1] * reel_step, og_col + direct[2] * reel_step, all_extmarks[reel_step + 1])

    if reel_step >= n_reel_steps - 1 then -- TODO code re-use here
      H.timer:stop()
      H.undraw_chains(buf_id)
      -- vim.wo.virtualedit = H.original_virtualedit
      -- H.current.draw_status = "finished"
      -- vim.defer_fn(function()
      H.current.grapple_status = false
      -- end, 100) -- TODO try w/o!
      return
    end

    reel_step = reel_step + 1
    wait_time = tick_ms --animation_func(step, n_steps)
    H.timer:set_repeat(wait_time)

    -- Stop the timer, and if it is repeating restart it using the
    -- repeat value as the timeout. If the timer has never been
    -- started before it raises EINVAL.
    H.timer:again()
  end)

  local reel_callback = function()
    -- end
    -- local reel_callback2 = function()
    H.original_virtualedit = vim.wo.virtualedit
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

-- Namespace for drawing vertical line
H.ns_id = vim.api.nvim_create_namespace("Grappler")

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
    options = { config.options, "table" },
    symbols = { config.symbols, "string" },
  })

  vim.validate({
    ["draw.delay"] = { config.draw.delay, "number" },
    -- ["draw.animation"] = { config.draw.animation, "function" },
    ["draw.priority"] = { config.draw.priority, "number" },
    ["draw.tick_ms"] = { config.draw.tick_ms, "number" },

    ["mappings.right"] = { config.mappings.up_right, "string" },
    ["mappings.up_right"] = { config.mappings.up_right, "string" },
    ["mappings.up"] = { config.mappings.up, "string" },
    ["mappings.up_left"] = { config.mappings.up_left, "string" },
    ["mappings.left"] = { config.mappings.up_left, "string" },
    ["mappings.down_left"] = { config.mappings.down_left, "string" },
    ["mappings.down"] = { config.mappings.down, "string" },
    ["mappings.down_right"] = { config.mappings.down_right, "string" },
    ["mappings.toggle_grapple_mode"] = { config.mappings.toggle_grapple_mode, "string" },
  })
  return config
end

H.apply_config = function(config)
  Grappler.config = config
  local maps = config.mappings

	--stylua: ignore start
	H.map('n', maps.toggle_grapple_mode, [[<Cmd>lua Grappler.toggle_grapple_mode()<CR>]], { desc = 'Go to indent scope top' })
	H.map('n', maps.up_right, [[<Cmd>lua Grappler.grapple({1,1}, true)<CR>]], { desc = 'Go to indent scope top' })

  -- H.map('n', maps.goto_top, [[<Cmd>lua Grappler.operator('temp', true)<CR>]], { desc = 'Go to indent scope top' })
  -- H.map('n', maps.goto_temp, [[<Cmd>lua Grappler.operator('temp', true)<CR>]], { desc = 'Go to indent scope top' })
  -- H.map('n', maps.goto_bottom, [[<Cmd>lua Grappler.operator('bottom', true)<CR>]], { desc = 'Go to indent scope bottom' })

  -- H.map('n', maps.goto_left, [[<Cmd>lua Grappler.operator('left', false)<CR>]], { desc = 'Go to indent scope left' })
  -- H.map('n', maps.goto_right, [[<Cmd>lua Grappler.operator('right', false)<CR>]], { desc = 'Go to indent scope right' })
  -- H.map('n', maps.goto_, [[<Cmd>lua Grappler.operator('left', true)<CR>]], { desc = 'Go to indent scope bottom' })

  -- H.map('x', maps.goto_top, [[<Cmd>lua Grappler.operator('top')<CR>]], { desc = 'Go to indent scope top' })
  -- H.map('x', maps.goto_bottom, [[<Cmd>lua Grappler.operator('bottom')<CR>]], { desc = 'Go to indent scope bottom' })
  -- H.map('x', maps.object_scope, '<Cmd>lua Grappler.textobject(false)<CR>', { desc = 'Object scope' })
  -- H.map('x', maps.object_scope_with_border, '<Cmd>lua Grappler.textobject(true)<CR>', { desc = 'Object scope with border' })

  -- H.map('o', maps.goto_top, [[<Cmd>lua Grappler.operator('top')<CR>]], { desc = 'Go to indent scope top' })
  -- H.map('o', maps.goto_bottom, [[<Cmd>lua Grappler.operator('bottom')<CR>]], { desc = 'Go to indent scope bottom' })
  -- H.map('o', maps.object_scope, '<Cmd>lua Grappler.textobject(false)<CR>', { desc = 'Object scope' })
  -- H.map('o', maps.object_scope_with_border, '<Cmd>lua Grappler.textobject(true)<CR>', { desc = 'Object scope with border' })
  --stylua: ignore start
end

H.is_disabled = function()
  return vim.g.miniindentscope_disable == true or vim.b.miniindentscope_disable == true
end

H.get_config = function(config)
  return vim.tbl_deep_extend("force", Grappler.config, vim.b.miniindentscope_config or {}, config or {})
end

-- like indexing a python string so char at 0-indexed idx
H.char_at = function(str, idx)
  return str:sub(idx + 1, idx + 1) -- account for 1-indexing bleh
end

H.is_idx_blank = function(line_content, col)
  local char = H.char_at(line_content, col)
  print("investigating_char: " .. char)
  if char == "" then
    return true
  end
  local char_left = H.char_at(line_content, col - 1)
  local char_right = H.char_at(line_content, col + 1)
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
  local target_line, target_col = original_line, original_col
  -- ideally if we dont find a target we won't grapple at all... but this seems like a reasonable default.
  --
  local max_col = vim.fn.winwidth(0) - 7 -- account for the left gutter 7 chars wide
  local max_line = vim.fn.line("$")

  local cur_line = original_line + direct[1]
  local cur_col = original_col + direct[2]

  local original_line_content = vim.api.nvim_buf_get_lines(0, original_line - 1, original_line, false)[1] -- [1] to grab the 1 and only line we requested
  local found_whitespace_yet = H.is_idx_blank(original_line_content, original_col)

  if cur_line > max_line then
    print("line: ", cur_line, "> max_line: ", max_line, ". returning early, no target.")
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
      target_col = cur_col -- TODO break
      not_done = false
    elseif cur_line > max_line then
      target_line = max_line
      target_col = cur_col -- TODO break
      not_done = false
    elseif cur_col < 0 then -- 0 indexed WTF why are they different?
      target_col = 0
      target_line = cur_line -- TODO break
      not_done = false
    elseif cur_col >= max_col then -- idk about the edges yet
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
        if not found_char and cur_col > 1 then
          local found_char_left = not H.is_idx_blank(line_content, cur_col - 1)
          local found_char_right = not H.is_idx_blank(line_content, cur_col + 1)
          if found_char_left and found_char_right then
            found_char = true
          end
        end
      end

      -- if haven't found char, then we are on whitespace,
      if not found_char then
        -- we either just launched from the line below (and it's step 0 right now)
        -- or we have been grappling thru a solid block of text (and step > 0)
        if not found_whitespace_yet and step > 0 then
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
        local delta_col = res_.delta_col
        -- - vim.fn.virtcol({ res.src.line, res.src.col })
        local delta_line = res_.delta_line
        local n_chain_steps = res_.n_chain_steps
        if n_chain_steps > 0 then
          target_col = cur_col
          target_line = cur_line
          not_done = false
        else
          print("skipping n_chain_steps == 0 (so 1 dist. away from target) grapple")
        end
      end
    end
    step = step + 1
    if step > 80 then
      vim.notify("tried to go >80 steps; hehe; maybe bug maybe infinite loop; best be safe out there")
      return
    end
    cur_line = cur_line + direct[1]
    cur_col = cur_col + direct[2]
  end
  return {
    found_target = true,
    target = { line = target_line, col = target_col },
    src = { line = original_line, col = original_col },
  }
end

-- H.cast_ray = function(line, indent, direction, opts)
--	 local final_line, increment = 1, -1
--	 if direction == "down" then
--		 final_line, increment = vim.fn.line("$"), 1
--	 end
--
--	 local min_indent = math.huge
--	 for l = line, final_line, increment do
--		 local new_indent = H.get_line_indent(l + increment, opts)
--		 if new_indent < indent then
--			 return l, min_indent
--		 end
--		 if new_indent < min_indent then
--			 min_indent = new_indent
--		 end
--	 end
--
--	 return final_line, min_indent
-- end

H.undraw_chains = function(buf_id)
  -- Don't operate outside of current event if able to verify
  -- if opts.event_id and opts.event_id ~= H.current.event_id then
  --	 return
  -- end

  pcall(vim.api.nvim_buf_clear_namespace, buf_id or 0, H.ns_id, 0, -1)

  H.current.draw_status = "none"
  H.current.scope = {}
end

H.undraw_scope = function(opts)
  opts = opts or {}

  -- Don't operate outside of current event if able to verify
  if opts.event_id and opts.event_id ~= H.current.event_id then
    return
  end

  pcall(vim.api.nvim_buf_clear_namespace, H.current.scope.buf_id or 0, H.ns_id, 0, -1)

  H.current.draw_status = "none"
  H.current.scope = {}
end

H.make_autodraw_opts = function(scope)
  local config = H.get_config()
  local res = {
    event_id = H.current.event_id,
    type = "animation",
    delay = config.draw.delay,
    -- animation_func = config.draw.animation,
    tick_ms = config.draw.tick_ms,
    priority = config.draw.priority,
  }

  return res
end

H.make_draw_function2 = function(buf_id, opts, direct, hook, reel)
  local current_event_id = opts.event_id
  local hl_group_chain = "GrapplerSymbolChain"
  local hl_group_hook = "GrapplerSymbolHook"

  local virt_text
  if hook == true then
    -- virt_text = { { "X", hl_group } }
    -- virt_text = { { "", hl_group_hook } }
    virt_text = { { "█", hl_group_hook } }
  else
    if direct[2] == 1 then
      if direct[1] == -1 then
        virt_text = { { "╱", hl_group_chain } }
      elseif direct[1] == 0 then
        virt_text = { { "-", hl_group_chain } }
      else
        virt_text = { { "╲", hl_group_chain } }
      end
    elseif direct[2] == 0 then
      virt_text = { { "|", hl_group_chain } }
    else -- col negative
      if direct[1] == 1 then
        virt_text = { { "╱", hl_group_chain } }
      elseif direct[1] == -1 then
        virt_text = { { "╲", hl_group_chain } }
      else
        virt_text = { { "-", hl_group_chain } }
      end
    end
  end
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

    -- Don't draw if disabled
    if H.is_disabled() then
      return false
    end

    if reel then
      local succ = pcall(vim.api.nvim_buf_del_extmark, buf_id, H.ns_id, extmark_id)
      if succ then
        if col < 0 then
          -- vim.notify("why r u trying to crash with setting cursor to col = " .. col)
          col = 0
        else
          vim.api.nvim_win_set_cursor(0, { line, col })
          -- TODO: for some reason nvim_win_set_cursor() has different x offset on lines with and without content
          -- and its affected by tabs, because a tab is a single character (a single column)
          -- not sure if its affected by tabs outside of virualedit tho
          local stupid_virtual_screen_offset = vim.fn.virtcol(".") - col - 1
          if stupid_virtual_screen_offset ~= 0 then
            vim.api.nvim_win_set_cursor(0, { line, col - stupid_virtual_screen_offset })
          end
          return true
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
-- Parameters:
-- {buffer} Buffer handle, or 0 for current buffer
-- {ns_id} Namespace id from nvim_create_namespace() or -1 for all namespaces
-- {start} Start of range: a 0-indexed (row, col) or valid extmark id (whose position defines the bound). api-indexing
-- {end} End of range (inclusive): a 0-indexed (row, col) or valid extmark id (whose position defines the bound). api-indexing
-- {opts} Optional parameters. Keys:
-- limit: Maximum number of marks to return
-- details: Whether to include the details dict
-- hl_name: Whether to include highlight group name instead of id, true if omitted
-- overlap: Also include marks which overlap the range, even if their start position is less than start
-- type: Filter marks by type: "highlight", "sign", "virt_text" and "virt_lines"
-- Return:
-- List of [extmark_id, row, col] tuples in "traversal order".																																		 start,		end

-- Utilities ------------------------------------------------------------------
H.error = function(msg)
  error(("(mini.indentscope) %s"):format(msg))
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

H.exit_visual_mode = function()
  local ctrl_v = vim.api.nvim_replace_termcodes("<C-v>", true, true, true)
  local cur_mode = vim.fn.mode()
  if cur_mode == "v" or cur_mode == "V" or cur_mode == ctrl_v then
    vim.cmd("normal! " .. cur_mode)
  end
end

return Grappler
