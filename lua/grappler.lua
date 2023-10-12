--- *mini.indentscope* Visualize and work with indent scope
--- *MiniIndentscope*
---
--- MIT License Copyright (c) 2022 Evgeni Chasnovski
---
--- ==============================================================================
---
--- Indent scope (or just "scope") is a maximum set of consecutive lines which
--- contains certain reference line (cursor line by default) and every member
--- has indent not less than certain reference indent ("indent at cursor" by
--- default: minimum between cursor column and indent of cursor line).
---
--- Features:
--- - Visualize scope with animated vertical line. It is very fast and done
---   automatically in a non-blocking way (other operations can be performed,
---   like moving cursor). You can customize debounce delay and animation rule.
---
--- - Customization of scope computation options can be done on global level
---   (in |MiniIndentscope.config|), for a certain buffer (using
---   `vim.b.miniindentscope_config` buffer variable), or within a call (using
---   `opts` variable in |MiniIndentscope.get_scope|).
---
--- - Customizable notion of a border: which adjacent lines with strictly lower
---   indent are recognized as such. This is useful for a certain filetypes
---   (for example, Python or plain text).
---
--- - Customizable way of line to be considered "border first". This is useful
---   if you want to place cursor on function header and get scope of its body.
---
--- - There are textobjects and motions to operate on scope. Support |count|
---   and dot-repeat (in operator pending mode).
---
--- # Setup~
---
--- This module needs a setup with `require('mini.indentscope').setup({})`
--- (replace `{}` with your `config` table). It will create global Lua table
--- `MiniIndentscope` which you can use for scripting or manually (with `:lua
--- MiniIndentscope.*`).
---
--- See |MiniIndentscope.config| for available config settings.
---
--- You can override runtime config settings locally to buffer inside
--- `vim.b.miniindentscope_config` which should have same structure as
--- `MiniIndentscope.config`. See |mini.nvim-buffer-local-config| for more details.
---
--- # Comparisons~
---
--- - 'lukas-reineke/indent-blankline.nvim':
---     - Its main functionality is about showing static guides of indent levels.
---     - Implementation of 'mini.indentscope' is similar to
---       'indent-blankline.nvim' (using |extmarks| on first column to be shown
---       even on blank lines). They can be used simultaneously, but it will
---       lead to one of the visualizations being on top (hiding) of another.
---
--- # Highlight groups~
---
--- * `MiniIndentscopeSymbol` - symbol showing on every line of scope if its
---   indent is multiple of 'shiftwidth'.
--- * `MiniIndentscopeSymbolOff` - symbol showing on every line of scope if its
---   indent is not multiple of 'shiftwidth'.
---   Default: links to `MiniIndentscopeSymbol`.
---
--- To change any highlight group, modify it directly with |:highlight|.
---
--- # Disabling~
---
--- To disable autodrawing, set `vim.g.miniindentscope_disable` (globally) or
--- `vim.b.miniindentscope_disable` (for a buffer) to `true`. Considering high
--- number of different scenarios and customization intentions, writing exact
--- rules for disabling module's functionality is left to user. See
--- |mini.nvim-disabling-recipes| for common recipes.

--- Drawing of scope indicator
---
--- Draw of scope indicator is done as iterative animation. It has the
--- following design:
--- - Draw indicator on origin line (where cursor is at) immediately. Indicator
---   is visualized as `MiniIndentscope.config.symbol` placed to the right of
---   scope's border indent. This creates a line from top to bottom scope edges.
--- - Draw upward and downward concurrently per one line. Progression by one
---   line in both direction is considered to be one step of animation.
--- - Before each step wait certain amount of time, which is decided by
---   "animation function". It takes next and total step numbers (both are one
---   or bigger) and returns number of milliseconds to wait before drawing next
---   step. Comparing to a more popular "easing functions" in animation (input:
---   duration since animation start; output: percent of animation done), it is
---   a discrete inverse version of its derivative. Such interface proved to be
---   more appropriate for kind of task at hand.
---
--- Special cases~
---
--- - When scope to be drawn intersects (same indent, ranges overlap) currently
---   visible one (at process or finished drawing), drawing is done immediately
---   without animation. With most common example being typing new text, this
---   feels more natural.
--- - Scope for the whole buffer is not drawn as it is isually redundant.
---   Technically, it can be thought as drawn at column 0 (because border
---   indent is -1) which is not visible.
---@tag MiniIndentscope-drawing

-- Module definition ==========================================================
local Grappler = {}
local H = {}

function serializeTable(val, name, skipnewlines, depth)
	skipnewlines = skipnewlines or false
	depth = depth or 0

	local tmp = string.rep(" ", depth)

	if name then
		tmp = tmp .. name .. " = "
	end

	if type(val) == "table" then
		tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

		for k, v in pairs(val) do
			tmp = tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
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
---@param config table|nil Module config table. See |MiniIndentscope.config|.
---
---@usage `require('mini.indentscope').setup({})` (replace `{}` with your `config` table)
Grappler.setup = function(config)
	-- TODO: Remove after Neovim<=0.6 support is dropped
	if vim.fn.has("nvim-0.7") == 0 then
		vim.notify(
			"(Neovim<0.7 is soft deprecated (module works but not supported)."
				.. " It will be deprecated after Neovim 0.9.0 release (module will not work)."
				.. " Please update your Neovim version."
		)
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
	-- 	[[augroup Grappler
	--        au!
	--        au CursorMoved,CursorMovedI                          * lua Grappler.auto_draw({ lazy = true })
	--        au TextChanged,TextChangedI,TextChangedP,WinScrolled * lua Grappler.auto_draw()
	--      augroup END]],
	-- 	false
	-- )

	-- if vim.fn.exists("##ModeChanged") == 1 then
	-- 	vim.api.nvim_exec(
	-- 		-- Call `auto_draw` on mode change to respect `miniindentscope_disable`
	-- 		[[augroup Grappler
	--          au ModeChanged *:* lua Grappler.auto_draw({ lazy = true })
	--        augroup END]],
	-- 		false
	-- 	)
	-- end

	-- Create highlighting
	vim.api.nvim_exec(
		[[hi default link GrapplerSymbol Delimiter
      hi default link GrapplerSymbolOff GrapplerSymbol]],
		false
	)
end

--- Module config
---
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@text # Options ~
---
--- - Options can be supplied globally (from this `config`), locally to buffer
---   (via `options` field of `vim.b.miniindentscope_config` buffer variable),
---   or locally to call (as argument to |MiniIndentscope.get_scope()|).
---
--- - Option `border` controls which line(s) with smaller indent to categorize
---   as border. This matters for textobjects and motions.
---   It also controls how empty lines are treated: they are included in scope
---   only if followed by a border. Another way of looking at it is that indent
---   of blank line is computed based on value of `border` option.
---   Here is an illustration of how `border` works in presense of empty lines:
--- >
---                              |both|bottom|top|none|
---   1|function foo()           | 0  |  0   | 0 | 0  |
---   2|                         | 4  |  0   | 4 | 0  |
---   3|    print('Hello world') | 4  |  4   | 4 | 4  |
---   4|                         | 4  |  4   | 2 | 2  |
---   5|  end                    | 2  |  2   | 2 | 2  |
--- <
---   Numbers inside a table are indent values of a line computed with certain
---   value of `border`. So, for example, a scope with reference line 3 and
---   right-most column has body range depending on value of `border` option:
---     - `border` is "both":   range is 2-4, border is 1 and 5 with indent 2.
---     - `border` is "top":    range is 2-3, border is 1 with indent 0.
---     - `border` is "bottom": range is 3-4, border is 5 with indent 0.
---     - `border` is "none":   range is 3-3, border is empty with indent `nil`.
---
--- - Option `indent_at_cursor` controls if cursor position should affect
---   computation of scope. If `true`, reference indent is a minimum of
---   reference line's indent and cursor column. In main example, here how
---   scope's body range differs depending on cursor column and `indent_at_cursor`
---   value (assuming cursor is on line 3 and it is whole buffer):
--- >
---     Column\Option true|false
---        1 and 2    2-5 | 2-4
---      3 and more   2-4 | 2-4
--- <
--- - Option `try_as_border` controls how to act when input line can be
---   recognized as a border of some neighbor indent scope. In main example,
---   when input line is 1 and can be recognized as border for inner scope,
---   value `try_as_border = true` means that inner scope will be returned.
---   Similar, for input line 5 inner scope will be returned if it is
---   recognized as border.
Grappler.config = {
	-- Draw options
	draw = {
		-- Delay (in ms) between event and start of drawing scope indicator
		delay = 69,

		-- Animation rule for scope's first drawing. A function which, given
		-- next and total step numbers, returns wait time (in ms). See
		-- |MiniIndentscope.gen_animation| for builtin options. To disable
		-- animation, use `require('mini.indentscope').gen_animation.none()`.
		--minidoc_replace_start animation = --<function: implements constant 20ms between steps>,
		-- animation = function(s, n)
		-- 	return 20
		-- end,
		tick_ms = 20,
		--minidoc_replace_end

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

	-- Which character to use for drawing scope indicator
	-- symbol = "╎",
	symbols = "/D",
}

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

Grappler.toggle_grapple_mode = function() -- grapple()
end

Grappler.clear_symbols = function() -- grapple()
end

Grappler.grapple = function(direct) -- grapple()
	print("grapple")
	local config = H.get_config()
	local tick_ms = config.draw.tick_ms
	local buf_id = vim.api.nvim_get_current_buf()
	-- local delays = {}
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line, col = cursor[1], cursor[2]
	local res = H.ray_cast(line, col, direct)
	print("res; " .. serializeTable(res))

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

	-- todo use a sensible opts structure or something...                 chains, reel
	local draw_func_chain = H.make_draw_function2(buf_id, draw_opts, direct, false, false)
	local draw_func_hook = H.make_draw_function2(buf_id, draw_opts, direct, true, false)
	local draw_func_reel = H.make_draw_function2(buf_id, draw_opts, direct, false, true)

	-- H.normalize_animation_opts()
	-- local animation_func = config.draw.animation --Grappler.gen_animation.linear2(100)

	H.current.draw_status = "drawing"
	local n_steps = math.abs(res.target.line - res.src.line) - 1

	print("target_line, col, n_steps: " .. res.target.line .. ", " .. res.target.col .. ", " .. n_steps)
	print("test:")
	print(vim.inspect(res))
	-- end

	-- Grappler.grapple_ = function(direct)
	local n_reel_steps = n_steps + 1 -- TODO: resolve this

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
		local chain_extmark_id = draw_func_chain(og_line + step * direct[1], og_col + step * direct[2])
		if chain_extmark_id == false then
			print("failed to put hook extmark")
		else
			table.insert(extmark_ids["chain"], chain_extmark_id)
		end
		if step >= n_steps - 1 then -- TODO code re-use here
			print("fin, stopping timer. " .. step)
			H.timer:stop()
			local final_offset = n_steps
			print("putting hook")
			local hook_extmark_id =
				draw_func_hook(og_line + final_offset * direct[1], og_col + final_offset * direct[2])
			if hook_extmark_id == false then
				print("failed to put hook extmark")
			else
				table.insert(extmark_ids["hook"], hook_extmark_id)
			end

			H.current.draw_status = "finished"
			vim.defer_fn(function()
				H.finished_callback()
			end, 300)
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
			-- print("Completed animation")
			H.current.draw_status = "finished"
			H.undraw_chains(buf_id)
			vim.wo.virtualedit = H.original_virtualedit
			H.timer:stop()
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
		vim.wo.virtualedit = "all"

		-- Start non-repeating timer without callback execution. This shouldn't be
		-- `timer:start(0, 0, draw_step)` because it will execute `draw_step` on the
		-- next redraw (flickers on window scroll).
		H.timer:start(10000000, 0, draw_reel_step)

		-- Draw step zero (at origin) immediately
		draw_reel_step()
	end
	--
	-- 	-- Start non-repeating timer without callback execution. This shouldn't be
	-- 	-- `timer:start(0, 0, draw_step)` because it will execute `draw_step` on the
	-- 	-- next redraw (flickers on window scroll).
	-- 	--
	-- 	--(timeout, repeat, callback)
	H.timer:start(10000000, 0, draw_step)
	--
	H.finished_callback = reel_callback

	-- Draw step zero (at origin) immediately
	draw_step()
end

Grappler.operator2 = function()
	-- function findTextAboveCursor()
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	local cursor_col = vim.api.nvim_win_get_cursor(0)[2]
	-- local max_line = vim.fn.line("$", bufwinid(0))

	for line = current_line - 1, 1, -1 do
		local line_content = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]
		if not line_content then
			break
		end

		if #line_content >= cursor_col then
			vim.api.nvim_win_set_cursor(0, { line, cursor_col })
			return
		end
	end

	-- If no suitable line is found, stay on the current line
	vim.api.nvim_win_set_cursor(0, { current_line, 1 })
end

--- Function for textobject mappings
---
--- Respects |count| and dot-repeat (in operator-pending mode). Doesn't work
--- for scope that is not shown (drawing indent less that zero).
---
---@param use_border boolean|nil Whether to include border in textobject. When
---   `true` and `try_as_border` option is `false`, allows "chaining" calls for
---   incremental selection.
Grappler.textobject = function(use_border)
	local scope = Grappler.get_scope()

	-- Don't support scope that can't be shown
	if H.scope_get_draw_indent(scope) < 0 then
		return
	end

	-- Allow chaining only if using border
	local count = use_border and vim.v.count1 or 1

	-- Make sequence of incremental selections
	for _ = 1, count do
		-- Try finish cursor on border
		local start, finish = "top", "bottom"
		if use_border and scope.border.bottom == nil then
			start, finish = "bottom", "top"
		end

		H.exit_visual_mode()
		Grappler.move_cursor(start, use_border, scope)
		vim.cmd("normal! V")
		Grappler.move_cursor(finish, use_border, scope)

		-- Use `try_as_border = false` to enable chaining
		scope = Grappler.get_scope(nil, nil, { try_as_border = false })

		-- Don't support scope that can't be shown
		if H.scope_get_draw_indent(scope) < 0 then
			return
		end
	end
end

-- Helper data ================================================================
-- Module default config
H.default_config = Grappler.config

-- Namespace for drawing vertical line
H.ns_id = vim.api.nvim_create_namespace("Grappler")

-- Timer for doing animation
H.timer = vim.loop.new_timer()

-- Table with current relevalnt data:
-- - `event_id` - counter for events.
-- - `scope` - latest drawn scope.
-- - `draw_status` - status of current drawing.
H.current = { event_id = 0, scope = {}, draw_status = "none" }

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

		-- ["mappings.object_scope"] = { config.mappings.object_scope, "string" },
		-- ["mappings.object_scope_with_border"] = { config.mappings.object_scope_with_border, "string" },
		-- ["mappings.goto_temp"] = { config.mappings.goto_temp, "string" },
		-- ["mappings.goto_top"] = { config.mappings.goto_top, "string" },
		-- ["mappings.goto_bottom"] = { config.mappings.goto_bottom, "string" },

		-- ["mappings.goto_left"] = { config.mappings.goto_left, "string" },
		-- ["mappings.goto_right"] = { config.mappings.goto_right, "string" },

		-- ["options.border"] = { config.options.border, "string" },
		-- ["options.indent_at_cursor"] = { config.options.indent_at_cursor, "boolean" },
		-- ["options.try_as_border"] = { config.options.try_as_border, "boolean" },
	})
	return config
end

H.apply_config = function(config)
	Grappler.config = config
	local maps = config.mappings

  --stylua: ignore start
	--
	--
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
--   ignore blank lines before line not recognized as border.
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

H.ray_cast = function(line, col, direct)
	local target_line, target_col = line, col
	local original_line, original_col = line, col
	-- print("setup from line: " .. line)
	--
	-- line = line - 1 -- for UR
	line = line + direct[1]
	col = col + direct[2]

	local max_col = vim.fn.winwidth(0) - 7
	-- local max_line = nvim_buf_line_count(vim.fn.bufnr())

	local max_line = vim.fn.line("$")
	print("max_line: " .. max_line)
	-- line = line - 1 -- for UR
	-- local found_target = false;
	local not_done = true
	while not_done do
		if line < 1 then
			target_line = 1 -- 1 indexed ughhh
			target_col = col -- TODO break
			not_done = false
		elseif line >= max_line - 1 then
			target_line = max_line - 1
			target_col = col -- TODO break
			not_done = false
		elseif col < 1 then
			target_col = col
			target_line = line -- TODO break
			not_done = false
		elseif col > max_col - 1 then -- idk about the edges yet
			target_col = col
			target_line = line -- TODO break
			not_done = false
		end

		if not_done == true then
			local line_content = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]
			-- print("checking line " .. line .. ": " .. line_content)
			if #line_content >= col then
				-- print("target?")
				target_col = col
				target_line = line
				not_done = false
			end
		end
		line = line + direct[1]
		col = col + direct[2]
	end
	-- print(
	-- 	"found target (line:" .. target_line .. ",col:" .. target_col .. ") @ dist." .. (target_line - original_line)
	-- )
	return {
		found_target = true,
		target = { line = target_line, col = target_col },
		src = { line = original_line, col = original_col },
	}
end

-- H.cast_ray = function(line, indent, direction, opts)
-- 	local final_line, increment = 1, -1
-- 	if direction == "down" then
-- 		final_line, increment = vim.fn.line("$"), 1
-- 	end
--
-- 	local min_indent = math.huge
-- 	for l = line, final_line, increment do
-- 		local new_indent = H.get_line_indent(l + increment, opts)
-- 		if new_indent < indent then
-- 			return l, min_indent
-- 		end
-- 		if new_indent < min_indent then
-- 			min_indent = new_indent
-- 		end
-- 	end
--
-- 	return final_line, min_indent
-- end

H.undraw_chains = function(buf_id)
	-- Don't operate outside of current event if able to verify
	-- if opts.event_id and opts.event_id ~= H.current.event_id then
	-- 	return
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
				print("setting cursor to col: " .. col)
				vim.api.nvim_win_set_cursor(0, { line, col })
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
-- List of [extmark_id, row, col] tuples in "traversal order".                                                                     start,    end

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
