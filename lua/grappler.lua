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
    [[hi default link GrapplerSymbol Delimiter
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

-- Define a function to highlight non-space characters in each line
function H.highlightNonSpaceCharacters()
  vim.notify("hi")
  -- Get the current buffer
  local current_buf = vim.api.nvim_get_current_buf()

  -- Get the total number of lines in the buffer
  local num_lines = vim.api.nvim_buf_line_count(current_buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line, col = cursor[1], cursor[2]

  -- Define the namespace for our highlights
  local ns_id = vim.api.nvim_create_namespace("highlight_non_space")

  -- Iterate through each line
  -- for line_num = 0, num_lines - 1 do
  -- Get the content of the current line
  local line_content = vim.api.nvim_buf_get_lines(current_buf, line, line + 1, false)[1]

  -- Create a table to store extmark options for this line
  --
  vim.cmd([[highlight NonSpaceHighlight guibg=#660040 gui=nocombine]])

  local extmark_opts = {
    hl_mode = "replace", -- Replace existing text color
    priority = 2,
    right_gravity = false,
    virt_text = { { "", "NonSpaceHighlight" } },
    virt_text_win_col = -1, -- TEMP (replaced)
    virt_text_pos = "overlay",
  }

  -- vim.cmd([[highlight IndentBlanklineIndent1 guibg=#292e40 guifg=#3b4261 gui=nocombine]])
  -- Iterate through characters in the line
  --
	--stylua: ignore

                   
  -- extmark_opts.end_col = 15 -- out of range??
  extmark_opts.virt_text_win_col = 7
  local res = vim.api.nvim_buf_set_extmark(current_buf, ns_id, 175, 0, extmark_opts) -- 0 is col but seems to have no effect, see virt_text_win_col idk why col does nothing
  vim.notify("res: " .. res)
  -- for col = 0, #line_content do
  --   local char = string.sub(line_content, col, col)
  --   if char ~= " " then
  --     -- Highlight non-space characters with a custom highlight group
  --     extmark_opts.hl_group = "NonSpaceHighlight" -- Change this to your desired highlight group
  --     -- Create an extmark for the non-space character
  --     -- vim.api.nvim_buf_set_extmark(current_buf, ns_id, line_num, col, extmark_opts)
  --     vim.api.nvim_buf_set_extmark(current_buf, ns_id, 167, 2, extmark_opts)
  --   end
  -- end
  -- end
end

-- Call the function to highlight non-space characters
-- highlightNonSpaceCharacters()

Grappler.toggle_grapple_mode = function() -- grapple()
end

Grappler.clear_symbols = function() -- grapple()
end

Grappler.grapple = function(direct) -- grapple()
  H.highlightNonSpaceCharacters()
end
Grappler.grapple2 = function(direct) -- grapple()
  if H.current.grapple_status == true then
    -- if H.current.draw_status == "drawing" then
    print("already drawing, u tryna crash me?")
    return
  end
  H.current.grapple_status = true
  H.current.draw_status = "drawing"
  local config = H.get_config()
  local tick_ms = config.draw.tick_ms
  local delay = config.draw.delay
  local buf_id = vim.api.nvim_get_current_buf()
  -- local delays = {}
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line, col = cursor[1], cursor[2]
  print("grapple from l,c(", line, ",", col, ")")
  local res = H.ray_cast(line, col, direct)
  print("res; " .. serialize_table(res))

  local draw_opts = {
    event_id = H.current.event_id,
    type = "animation",
    delay = config.draw.delay,
    tick_ms = config.draw.tick_ms,
    priority = config.draw.priority,
  }
  if not res.found_target then
    print("no target found")
    return
  end

  -- todo use a sensible opts structure or something...								 chains, reel
  local draw_func_chain = H.make_draw_function2(buf_id, draw_opts, direct, false, false)
  local draw_func_hook = H.make_draw_function2(buf_id, draw_opts, direct, true, false)
  local draw_func_reel = H.make_draw_function2(buf_id, draw_opts, direct, false, true)

  -- H.normalize_animation_opts()
  -- local animation_func = config.draw.animation --Grappler.gen_animation.linear2(100)

  local delta_col, delta_line = (res.target.line - res.src.line), (res.target.col - res.src.col)
  local n_chain_steps = math.max(math.abs(delta_col), math.abs(delta_line)) - 1
  print("delta_line: " .. delta_line)
  print("delta_col: " .. delta_col)
  print("n_steps: " .. n_chain_steps)

  print("target_line, col, n_steps: " .. res.target.line .. ", " .. res.target.col .. ", " .. n_chain_steps)

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
    print("draw_step " .. step)
    local cur_chain_line = og_line + step * direct[1]
    local cur_chain_col = og_col + step * direct[2]
    local chain_extmark_id = draw_func_chain(cur_chain_line, cur_chain_col)
    if chain_extmark_id == false then
      print("failed to put chain extmark")
    else
      print("put chain at cur_chain_line, cur_chain_col =" .. cur_chain_line .. ", " .. cur_chain_col)
      table.insert(extmark_ids["chain"], chain_extmark_id)
    end
    if step >= n_chain_steps - 1 then -- TODO code re-use here
      print("fin, stopping timer. " .. step)
      H.timer:stop()
      local final_offset = n_chain_steps
      print("putting hook")
      local hook_extmark_id = draw_func_hook(og_line + final_offset * direct[1], og_col + final_offset * direct[2])
      if hook_extmark_id == false then
        print("failed to put hook extmark")
      else
        table.insert(extmark_ids["hook"], hook_extmark_id)
      end

      H.current.draw_status = "finished"
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
    -- print("draw_reel_step, n_steps=" .. n_reel_steps .. ",step=" .. reel_step)
    local all_extmarks = extmark_ids.all()
    -- print("all_extmarks: " .. serializeTable(extmark_ids))
    -- print(": " .. all_extmarks[reel_step + 1])
    local succ =
      draw_func_reel(og_line + direct[1] * reel_step, og_col + direct[2] * reel_step, all_extmarks[reel_step + 1])

    if reel_step >= n_reel_steps - 1 then -- TODO code re-use here
      H.timer:stop()
      H.undraw_chains(buf_id)
      -- vim.wo.virtualedit = H.original_virtualedit
      -- print("OG!")
      print(H.original_virtualedit)
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
    print("reel_callback, n_reel_steps=" .. n_reel_steps)
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
H.current = { event_id = 0, draw_status = "none", grapple_status = false }

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

-- Scope ----------------------------------------------------------------------
-- Line indent:
-- - Equals output of `vim.fn.indent()` in case of non-blank line.
-- - Depends on `MiniIndentscope.config.options.border` in such way so as to
--	 ignore blank lines before line not recognized as border.
H.get_line_indent = function(line, opts)
  local prev_nonblank = vim.fn.prevnonblank(line)
  local res = vim.fn.indent(prev_nonblank)

  -- Compute indent of blank line depending on `options.border` values
  if line ~= prev_nonblank then
    local next_indent = vim.fn.indent(vim.fn.nextnonblank(line))
    local blank_rule = H.blank_indent_funs[opts.border]
    res = blank_rule(res, next_indent)
  end

  return res
end

function findNonWhitespaceIndices(line)
  local pattern = "%S"
  local firstIndex = string.find(line, pattern)
  local lastIndex = string.find(string.reverse(line), pattern)

  if firstIndex then
    lastIndex = #line - lastIndex + 1
  end

  if not firstIndex or not lastIndex then
    firstIndex = nil
    lastIndex = nil
  end

  return firstIndex, lastIndex
end

-- like indexing a python string so char at 0-indexed idx
H.char_at = function(str, idx)
  return str:sub(idx + 1, idx + 1) -- account for 1-indexing bleh
end
H.is_idx_blank = function(line_content, col)
  local char = H.char_at(line_content, col)
  local match = char:match("%s")
  -- print("investigating_char: " .. char)
  -- print("char:match for whitespace:", char:match("%s"))
  -- print("my version: ", char:match("%s") or false)
  return match ~= nil
  -- return char:match("%s") or false
end
H.ray_cast = function(original_line, original_col, direct)
  local target_line, target_col = original_line, original_col
  -- ideally if we dont find a target we won't grapple at all... but this seems like a reasonable default.
  --
  -- print("setup from line: " .. line)
  --
  local max_col = vim.fn.winwidth(0) - 7
  -- local max_line = nvim_buf_line_count(vim.fn.bufnr())

  local max_line = vim.fn.line("$")

  -- line = line - 1 -- for UR
  local cur_line = original_line + direct[1]
  local cur_col = original_col + direct[2]

  local original_line_content = vim.api.nvim_buf_get_lines(0, original_line - 1, original_line, false)[1] -- [1] to grab the 1 and only line we requested
  -- local first_step_line_content = vim.api.nvim_buf_get_lines(0, cur_line - 1, cur_line, true)[1] -- [1] to grab the 1 and only line we requested
  local found_whitespace_yet = H.is_idx_blank(original_line_content, original_col)
  -- local found_whitespace_yet = H.is_idx_blank(first_step_line_content, cur_col)

  print("original col was whitespace: ", found_whitespace_yet)

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
      print("found target due to line: ", cur_line, "< 1")
      target_line = 1 -- 1 indexed ughhh
      target_col = cur_col -- TODO break
      not_done = false
    elseif cur_line >= max_line then
      print("found target due to line: ", cur_line, ">= max_line == ", max_line)
      target_line = max_line
      target_col = cur_col -- TODO break
      not_done = false
    elseif cur_col < 0 then -- 0 indexed WTF why are they different?
      print("found target due to col: ", cur_col, "< 0")
      target_col = 0
      target_line = cur_line -- TODO break
      not_done = false
    elseif cur_col >= max_col then -- idk about the edges yet
      print("found target due to col: ", cur_col, ">= max_col == ", max_col)
      target_col = max_col
      target_line = cur_line -- TODO break
      not_done = false
    end

    if not_done == true then
      local line_content = vim.api.nvim_buf_get_lines(0, cur_line - 1, cur_line, false)[1] -- [1] to grab the 1 and only line we requested
      print("line_content[line=", cur_line, ",col=", cur_col, "]=", H.char_at(line_content, cur_col))
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
      print("found_char: ", found_char, ", w/ found_whitespace_yet == ", found_whitespace_yet)
      -- if not found_char then
      --	 if not found_whitespace_yet then
      --		 found_whitespace_yet = true
      -- end
      --

      -- if haven't found char, then we are on whitespace,
      if not found_char then
        -- we either just launched from the line below (and it's step 0 right now)
        -- or we have been grappling thru a solid block of text (and step > 0)
        if not found_whitespace_yet and step > 0 then
          target_line, target_col = cur_line - direct[1], cur_col - direct[2]
          print("finally hit whitespace @ l,c:", cur_line, ",", cur_col)
          print("setting hook just behind it, at ..." .. target_line .. "," .. target_col)
          not_done = false
        else
          found_whitespace_yet = true
        end
        -- if steps == 0
        -- end
      elseif found_whitespace_yet and found_char then
        print("matched @ l,c:", cur_line, ",", cur_col)

        -- now lets make sure its not just a single space

        -- want to avoid 1-distance grapples inside of a block of text eg.
        --	 eg. if we grapple up-right  from the cursor, do we want to land on
        -- X, Y, or Z? Im gonna say never X so Y by default.
        --
        -- cccc cccc Z---
        --
        -- bbbb --Y- bbbb
        -- aaaa -X-- aaaa
        -- blah █lah blah
        local delta_col, delta_line = (cur_line - original_line), (cur_col - original_col)
        local n_chain_steps = math.max(math.abs(delta_col), math.abs(delta_line)) - 1
        if n_chain_steps > 0 then
          target_col = cur_col
          target_line = cur_line
          not_done = false
        else
          print("skipping 0-chain-step (so 1 total step) grapple")
        end
      end
    end
    step = step + 1
    if step > 80 then
      vim.notify("tried to go >80 steps hehe")
      return
    end
    cur_line = cur_line + direct[1]
    cur_col = cur_col + direct[2]
  end
  -- print(
  --	 "found target (line:" .. target_line .. ",col:" .. target_col .. ") @ dist." .. (target_line - original_line)
  -- )
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
  local hl_group = "GrapplerSymbol"

  local virt_text
  if hook == true then
    -- print("hook")
    -- virt_text = { { "X", hl_group } }
    virt_text = { { "", hl_group } }
  else
    -- print("chain")
    if direct[2] == 1 then
      if direct[1] == -1 then
        virt_text = { { "╱", hl_group } }
      elseif direct[1] == 0 then
        virt_text = { { "-", hl_group } }
      else
        virt_text = { { "╲", hl_group } }
      end
    elseif direct[2] == 0 then
      virt_text = { { "|", hl_group } }
    else -- col negative
      if direct[1] == 1 then
        virt_text = { { "╱", hl_group } }
      elseif direct[1] == -1 then
        virt_text = { { "╲", hl_group } }
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
        -- print("deleted extmark")
        -- print("cursor currently at ")
        print("setting cursor to line: " .. line .. ", col: " .. col)
        vim.api.nvim_win_set_cursor(0, { line, col })
        -- TODO, for some reason nvim_win_set_cursor() has different x offset on lines with and without content
        -- and its affected by tabs, because a tab is a single character (a single column)
        -- not sure if its affected by tabs outside of virualedit tho
        local stupid_virtual_screen_offset = vim.fn.virtcol(".") - col - 1
        if stupid_virtual_screen_offset ~= 0 then
          vim.api.nvim_win_set_cursor(0, { line, col - stupid_virtual_screen_offset })
        end
        return true
      end
      print("failed to del extmark w/ id (lemmeguess_nil_lol:" .. extmark_id .. ")")
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
