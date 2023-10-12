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
	vim.notify("setup config")

	-- Apply config
	H.apply_config(config)

	-- Module behavior
	vim.api.nvim_exec(
		[[augroup Grappler
        au!
        au CursorMoved,CursorMovedI                          * lua Grappler.auto_draw({ lazy = true })
        au TextChanged,TextChangedI,TextChangedP,WinScrolled * lua Grappler.auto_draw()
      augroup END]],
		false
	)

	if vim.fn.exists("##ModeChanged") == 1 then
		vim.api.nvim_exec(
			-- Call `auto_draw` on mode change to respect `miniindentscope_disable`
			[[augroup Grappler
          au ModeChanged *:* lua Grappler.auto_draw({ lazy = true })
        augroup END]],
			false
		)
	end

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
		object_scope = "ii",
		object_scope_with_border = "ai",

		-- Motions (jump to respective border line; if not present - body line)
		goto_left = "[l",
		goto_right = "[r",
		goto_top = "[i",
		goto_bottom = "]i",
	},

	-- Options which control scope computation
	options = {
		-- Type of scope's border: which line(s) with smaller indent to
		-- categorize as border. Can be one of: 'both', 'top', 'bottom', 'none'.
		border = "both",

		-- Whether to use cursor column when computing reference indent.
		-- Useful to see incremental scopes with horizontal cursor movements.
		indent_at_cursor = true,

		-- Whether to first check input line to be a border of adjacent scope.
		-- Use it if you want to place cursor on function header to get scope of
		-- its body.
		try_as_border = false,
	},

	-- Which character to use for drawing scope indicator
	-- symbol = "╎",
	symbols = "/D",
}
--minidoc_afterlines_end

-- Module functionality =======================================================
--- Compute indent scope
---
--- Indent scope (or just "scope") is a maximum set of consecutive lines which
--- contains certain reference line (cursor line by default) and every member
--- has indent not less than certain reference indent ("indent at column" by
--- default). Here "indent at column" means minimum between input column value
--- and indent of reference line. When using cursor column, this allows for a
--- useful interactive view of nested indent scopes by making horizontal
--- movements within line.
---
--- Options controlling actual computation is taken from these places in order:
--- - Argument `opts`. Use it to ensure independence from other sources.
--- - Buffer local variable `vim.b.miniindentscope_config` (`options` field).
---   Useful to define local behavior (for example, for a certain filetype).
--- - Global options from |MiniIndentscope.config|.
---
--- Algorithm overview~
---
--- - Compute reference "indent at column". Reference line is an input `line`
---   which might be modified to one of its neighbors if `try_as_border` option
---   is `true`: if it can be viewed as border of some neighbor scope, it will.
--- - Process upwards and downwards from reference line to search for line with
---   indent strictly less than reference one. This is like casting rays up and
---   down from reference line and reference indent until meeting "a wall"
---   (character to the right of indent or buffer edge). Latest line before
---   meeting is a respective end of scope body. It always exists because
---   reference line is a such one.
--- - Based on top and bottom lines with strictly lower indent, construct
---   scopes's border. The way it is computed is decided based on `border`
---   option (see |MiniIndentscope.config| for more information).
--- - Compute border indent as maximum indent of border lines (or reference
---   indent minus one in case of no border). This is used during drawing
---   visual indicator.
---
--- Indent computation~
---
--- For every line indent is intended to be computed unambiguously:
--- - For "normal" lines indent is an output of |indent()|.
--- - Indent is `-1` for imaginary lines 0 and past last line.
--- - For blank and empty lines indent is computed based on previous
---   (|prevnonblank()|) and next (|nextnonblank()|) non-blank lines. The way
---   it is computed is decided based on `border` in order to not include blank
---   lines at edge of scope's body if there is no border there. See
---   |MiniIndentscope.config| for a details example.
---
-- MiniIndentscope.goto_line = function(line, col, opts)
-- 	opts = H.get_config({ options = opts }).options
-- 	-- Compute default `line` and\or `col`
-- 	if not (line and col) then
-- 		local curpos = vim.fn.getcurpos()
--
-- 		line = line or curpos[2]
-- 		line = opts.try_as_border and H.border_correctors[opts.border](line, opts) or line
--
-- 		-- Use `curpos[5]` (`curswant`, see `:h getcurpos()`) to account for blank
-- 		-- and empty lines.
-- 		col = col or (opts.indent_at_cursor and curpos[5] or math.huge)
-- 	end
--
-- 	-- Make early return
-- 	local body = { indent = indent }
-- 	if indent <= 0 then
-- 		body.top, body.bottom, body.indent = 1, vim.fn.line("$"), line_indent
-- 	else
-- 		local up_min_indent, down_min_indent
-- 		body.top, up_min_indent = H.cast_ray(line, indent, "up", opts)
-- 		body.bottom, down_min_indent = H.cast_ray(line, indent, "down", opts)
-- 		body.indent = math.min(line_indent, up_min_indent, down_min_indent)
-- 	end
-- 	-- return {
-- 	-- 	body = body,
-- 	-- 	border = H.border_from_body[opts.border](body, opts),
-- 	-- 	buf_id = vim.api.nvim_get_current_buf(),
-- 	-- 	reference = { line = line, column = col, indent = indent },
-- 	-- }
-- end

---@param line number|nil Input line number (starts from 1). Can be modified to a
---   neighbor if `try_as_border` is `true`. Default: cursor line.
---@param col number|nil Column number (starts from 1). Default: if
---   `indent_at_cursor` option is `true` - cursor column from `curswant` of
---   |getcurpos()| (allows for more natural behavior on empty lines);
---   `math.huge` otherwise in order to not incorporate cursor in computation.
---@param opts table|nil Options to override global or buffer local ones (see
---   |MiniIndentscope.config|).
---
---@return table Table with scope information:
---   - <body> - table with <top> (top line of scope, inclusive), <bottom>
---     (bottom line of scope, inclusive), and <indent> (minimum indent withing
---     scope) keys. Line numbers start at 1.
---   - <border> - table with <top> (line of top border, might be `nil`),
---     <bottom> (line of bottom border, might be `nil`), and <indent> (indent
---     of border) keys. Line numbers start at 1.
---   - <buf_id> - identifier of current buffer.
---   - <reference> - table with <line> (reference line), <column> (reference
---     column), and <indent> ("indent at column") keys.
--
Grappler.get_scope = function(line, col, opts)
	opts = H.get_config({ options = opts }).options

	-- Compute default `line` and\or `col`
	if not (line and col) then
		local curpos = vim.fn.getcurpos()

		line = line or curpos[2]
		line = opts.try_as_border and H.border_correctors[opts.border](line, opts) or line

		-- Use `curpos[5]` (`curswant`, see `:h getcurpos()`) to account for blank
		-- and empty lines.
		col = col or (opts.indent_at_cursor and curpos[5] or math.huge)
	end

	-- Compute "indent at column"
	local line_indent = H.get_line_indent(line, opts)
	local indent = math.min(col, line_indent)

	-- Make early return
	local body = { indent = indent }
	if indent <= 0 then
		body.top, body.bottom, body.indent = 1, vim.fn.line("$"), line_indent
	else
		local up_min_indent, down_min_indent
		body.top, up_min_indent = H.cast_ray(line, indent, "up", opts)
		body.bottom, down_min_indent = H.cast_ray(line, indent, "down", opts)
		body.indent = math.min(line_indent, up_min_indent, down_min_indent)
	end

	return {
		body = body,
		border = H.border_from_body[opts.border](body, opts),
		buf_id = vim.api.nvim_get_current_buf(),
		reference = { line = line, column = col, indent = indent },
	}
end

--- Auto draw scope indicator based on movement events
---
--- Designed to be used with |autocmd|. No need to use it directly, everything
--- is setup in |MiniIndentscope.setup|.
---
---@param opts table|nil Options.
Grappler.auto_draw = function(opts)
	-- vim.notify("hi")
end
-- TODO: start here

--- Undraw currently visible scope manually
Grappler.undraw = function()
	H.undraw_scope()
end
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
-- Grappler.gen_animation.linear2 = function(duration)
-- 	return function(step, n_steps)
-- 		return (duration / n_steps) * step
-- 	end
-- end

--- Move cursor within scope
---
--- Cursor is placed on a first non-blank character of target line.
---
---@param side string One of "top" or "bottom".
---@param use_border boolean|nil Whether to move to border or withing scope's body.
---   If particular border is absent, body is used.
---@param scope table|nil Scope to use. Default: output of |MiniIndentscope.get_scope()|.
Grappler.move_cursor = function(side, use_border, scope)
	scope = scope or Grappler.get_scope()

	-- This defaults to body's side if it is not present in border
	local target_line = 0
	if side == "left" then
		local original_line = vim.fn.line(".")

		target_line = use_border and scope.border["bottom"] or scope.body["bottom"]
		target_line = math.min(math.max(target_line, 1), vim.fn.line("$"))

		-- jump to end of scope (line), and 0 (far left column)
		vim.api.nvim_win_set_cursor(0, { target_line, 0 })

		-- bring cursor to our actual target
		vim.cmd("normal! ^")

		local correct_column = vim.fn.col(".")

		vim.api.nvim_win_set_cursor(0, { original_line, correct_column })
		vim.cmd("normal! h") -- move left one
	else
		target_line = use_border and scope.border[side] or scope.body[side]
		target_line = math.min(math.max(target_line, 1), vim.fn.line("$"))
		vim.api.nvim_win_set_cursor(0, { target_line, 0 })
		-- Move to first non-blank character to allow chaining scopes
		vim.cmd("normal! ^")
	end
end

Grappler.operatorUR = function()
	vim.notify("hi operatorUR")
	local config = H.get_config()
	local tick_ms = config.draw.tick_ms
	local buf_id = vim.api.nvim_get_current_buf()
	-- local delays = {}
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line, col = cursor[1], cursor[2]
	local res = H.UR_ray(line, col)

	local draw_opts = {
		event_id = H.current.event_id,
		type = "animation",
		delay = config.draw.delay,
		tick_ms = config.draw.tick_ms,
		priority = config.draw.priority,
	}
	if not res.found_target then
		vim.notify("no target found")
		return
	end

	-- todo use a sensible opts structure or something...                 chains, reel
	local draw_func_chain = H.make_draw_function2(buf_id, draw_opts, "UR", false, false)
	local draw_func_hook = H.make_draw_function2(buf_id, draw_opts, "UR", true, false)
	local draw_func_reel = H.make_draw_function2(buf_id, draw_opts, "UR", false, true)

	-- H.normalize_animation_opts()
	-- local animation_func = config.draw.animation --Grappler.gen_animation.linear2(100)

	H.current.draw_status = "drawing"
	local n_steps = math.abs(res.target.line - res.src.line) - 1
	local n_reel_steps = n_steps + 1 -- TODO: resolve this

	-- don't draw chain on cursor
	local og_line, og_col = line - 1, col + 1
	local step, wait_time = 0, 0
	local reel_step = 0

	local extmark_ids = { chain = {}, hook = {} }
	extmark_ids.all = function()
		return array_concat(extmark_ids.chain, extmark_ids.hook)
	end

	local draw_step = vim.schedule_wrap(function()
		-- vim.notify(
		-- 	"draw_step, n_steps="
		-- 		.. n_steps
		-- 		.. ",step="
		-- 		.. step
		-- 		.. ",chain_extmark_ids=("
		-- 		.. serializeTable(extmark_ids)
		-- 		.. ")"
		-- )
		local chain_extmark_id = draw_func_chain(og_line - step, og_col + step)
		table.insert(extmark_ids["chain"], chain_extmark_id)
		if step >= n_steps - 1 then -- TODO code re-use here
			step = step + 1
			local hook_extmark_id = draw_func_hook(og_line - step, og_col + step)
			table.insert(extmark_ids["hook"], hook_extmark_id)

			-- vim.notify(
			-- 	"Completed animation, calling finished_callback, n_steps="
			-- 		.. n_steps
			-- 		.. ",step="
			-- 		.. step
			-- 		.. ",chain_extmark_ids="
			-- 		.. serializeTable(extmark_ids)
			-- 		.. ", calling finished_callback"
			-- )
			H.current.draw_status = "finished"
			H.timer:stop()
			vim.defer_fn(function()
				H.finished_callback()
			end, 500)
			return
		end

		step = step + 1
		wait_time = tick_ms --animation_func(step, n_steps)

		-- Repeat value of `timer` seems to be rounded down to milliseconds. This
		-- means that values less than 1 will lead to timer stop repeating. Instead
		-- call next step function directly.
		H.timer:set_repeat(wait_time)

		-- Restart `wait_time` only if it is actually used. Do this accounting
		-- actually set repeat time.
		-- wait_time = wait_time - H.timer:get_repeat()

		-- Usage of `again()` is needed to overcome the fact that it is called
		-- inside callback and to restart initial timer. Mainly this is needed
		-- only in case of transition from 'non-repeating' timer to 'repeating'
		-- one in case of complex animation functions. See
		-- https://docs.libuv.org/en/v1.x/timer.html#api
		H.timer:again()
	end)

	local draw_reel_step_vb = function(step, n_steps)
		vim.notify("step vb ran!")
		vim.api.nvim_out_write("test")
	end

	local draw_reel_step = vim.schedule_wrap(function()
		vim.notify("draw_reel_step, n_steps=" .. n_reel_steps .. ",step=" .. reel_step)
		local all_extmarks = extmark_ids.all()
		local succ = draw_func_reel(og_line - reel_step, og_col + reel_step, all_extmarks[reel_step + 1])

		if reel_step >= n_reel_steps - 1 then -- TODO code re-use here
			vim.notify("Completed animation")
			H.current.draw_status = "finished"
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
		vim.notify("reel_callback, n_reel_steps=" .. n_reel_steps)
		-- 		local original_virtualedit = vim.wo.virtualedit
		-- 		vim.wo.virtualedit = "all"
		--
		-- 		-- Start non-repeating timer without callback execution. This shouldn't be
		-- 		-- `timer:start(0, 0, draw_step)` because it will execute `draw_step` on the
		-- 		-- next redraw (flickers on window scroll).
		-- H.timer:start(10000000, 0, draw_reel_step_vb)
		H.timer:start(10000000, 0, draw_reel_step)
		--
		-- 		-- Draw step zero (at origin) immediately
		draw_reel_step()
		--
		-- 		vim.wo.virtualedit = original_virtualedit
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
	local max_line = vim.api.nvim_buf_line_count(0)

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

--- Function for motion mappings
---
--- Move to a certain side of border. Respects |count| and dot-repeat (in
--- operator-pending mode). Doesn't move cursor for scope that is not shown
--- (drawing indent less that zero).
---
---@param side string One of "top" or "bottom".
---@param add_to_jumplist boolean|nil Whether to add movement to jump list. It is
---   `true` only for Normal mode mappings.
Grappler.operator = function(side, add_to_jumplist)
	-- if moving left, and already on the scope line, presumably we don't want to just stay in place
	if side == "left" then
		vim.cmd("normal! h") -- move left one
	end

	local scope = Grappler.get_scope()
	if side == "right" then
		local original_col = vim.fn.col(".")
		local last_col = vim.fn.col("$")
		local newscope = Grappler.get_scope()
		while (newscope.body.top == scope.body.top) and (vim.fn.col(".") < last_col - 1) do
			vim.cmd("normal! l") -- move right one, check scope again lol
			newscope = Grappler.get_scope()
		end
		-- if we didnt find a new scope, return to where we were
		if newscope.body.top == scope.body.top then
			vim.api.nvim_win_set_cursor(0, { vim.fn.line("."), original_col - 1 })
		end
		return
	end

	-- Don't support scope that can't be shown
	if H.scope_get_draw_indent(scope) < 0 then
		return
	end

	-- Add movement to jump list. Needs remembering `count1` before that because
	-- it seems to reset it to 1.
	local count = vim.v.count1
	if add_to_jumplist then
		vim.cmd("normal! m`")
	end

	-- Make sequence of jumps
	for _ = 1, count do
		Grappler.move_cursor(side, true, scope)
		-- Use `try_as_border = false` to enable chaining
		scope = Grappler.get_scope(nil, nil, { try_as_border = false })

		-- Don't support scope that can't be shown
		if H.scope_get_draw_indent(scope) < 0 then
			return
		end
	end
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

-- Functions to compute indent in ambiguous cases
H.indent_funs = {
	["min"] = function(top_indent, bottom_indent)
		return math.min(top_indent, bottom_indent)
	end,
	["max"] = function(top_indent, bottom_indent)
		return math.max(top_indent, bottom_indent)
	end,
	["top"] = function(top_indent, bottom_indent)
		return top_indent
	end,
	["bottom"] = function(top_indent, bottom_indent)
		return bottom_indent
	end,
}

-- Functions to compute indent of blank line to satisfy `config.options.border`
H.blank_indent_funs = {
	["none"] = H.indent_funs.min,
	["top"] = H.indent_funs.bottom,
	["bottom"] = H.indent_funs.top,
	["both"] = H.indent_funs.max,
}

-- Functions to compute border from body
H.border_from_body = {
	["none"] = function(body, opts)
		return {}
	end,
	["top"] = function(body, opts)
		return { top = body.top - 1, indent = H.get_line_indent(body.top - 1, opts) }
	end,
	["bottom"] = function(body, opts)
		return { bottom = body.bottom + 1, indent = H.get_line_indent(body.bottom + 1, opts) }
	end,
	["both"] = function(body, opts)
		return {
			top = body.top - 1,
			bottom = body.bottom + 1,
			indent = math.max(H.get_line_indent(body.top - 1, opts), H.get_line_indent(body.bottom + 1, opts)),
		}
	end,
}

-- Functions to correct line in case it is a border
H.border_correctors = {
	["none"] = function(line, opts)
		return line
	end,
	["top"] = function(line, opts)
		local cur_indent, next_indent = H.get_line_indent(line, opts), H.get_line_indent(line + 1, opts)
		return (cur_indent < next_indent) and (line + 1) or line
	end,
	["bottom"] = function(line, opts)
		local prev_indent, cur_indent = H.get_line_indent(line - 1, opts), H.get_line_indent(line, opts)
		return (cur_indent < prev_indent) and (line - 1) or line
	end,
	["both"] = function(line, opts)
		local prev_indent, cur_indent, next_indent =
			H.get_line_indent(line - 1, opts), H.get_line_indent(line, opts), H.get_line_indent(line + 1, opts)

		if prev_indent <= cur_indent and next_indent <= cur_indent then
			return line
		end

		-- If prev and next indents are equal and bigger than current, prefer next
		if prev_indent <= next_indent then
			return line + 1
		end

		return line - 1
	end,
}

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

		["mappings.object_scope"] = { config.mappings.object_scope, "string" },
		["mappings.object_scope_with_border"] = { config.mappings.object_scope_with_border, "string" },
		-- ["mappings.goto_temp"] = { config.mappings.goto_temp, "string" },
		["mappings.goto_top"] = { config.mappings.goto_top, "string" },
		["mappings.goto_bottom"] = { config.mappings.goto_bottom, "string" },

		["mappings.goto_left"] = { config.mappings.goto_left, "string" },
		["mappings.goto_right"] = { config.mappings.goto_right, "string" },

		["options.border"] = { config.options.border, "string" },
		["options.indent_at_cursor"] = { config.options.indent_at_cursor, "boolean" },
		["options.try_as_border"] = { config.options.try_as_border, "boolean" },
	})
	return config
end

H.apply_config = function(config)
	Grappler.config = config
	local maps = config.mappings

  --stylua: ignore start
  H.map('n', maps.goto_top, [[<Cmd>lua Grappler.operator('temp', true)<CR>]], { desc = 'Go to indent scope top' })
  -- H.map('n', maps.goto_temp, [[<Cmd>lua Grappler.operator('temp', true)<CR>]], { desc = 'Go to indent scope top' })
  H.map('n', maps.goto_bottom, [[<Cmd>lua Grappler.operator('bottom', true)<CR>]], { desc = 'Go to indent scope bottom' })

  H.map('n', maps.goto_left, [[<Cmd>lua Grappler.operator('left', false)<CR>]], { desc = 'Go to indent scope left' })
  H.map('n', maps.goto_right, [[<Cmd>lua Grappler.operator('right', false)<CR>]], { desc = 'Go to indent scope right' })
  -- H.map('n', maps.goto_, [[<Cmd>lua Grappler.operator('left', true)<CR>]], { desc = 'Go to indent scope bottom' })

  H.map('x', maps.goto_top, [[<Cmd>lua Grappler.operator('top')<CR>]], { desc = 'Go to indent scope top' })
  H.map('x', maps.goto_bottom, [[<Cmd>lua Grappler.operator('bottom')<CR>]], { desc = 'Go to indent scope bottom' })
  H.map('x', maps.object_scope, '<Cmd>lua Grappler.textobject(false)<CR>', { desc = 'Object scope' })
  H.map('x', maps.object_scope_with_border, '<Cmd>lua Grappler.textobject(true)<CR>', { desc = 'Object scope with border' })

  H.map('o', maps.goto_top, [[<Cmd>lua Grappler.operator('top')<CR>]], { desc = 'Go to indent scope top' })
  H.map('o', maps.goto_bottom, [[<Cmd>lua Grappler.operator('bottom')<CR>]], { desc = 'Go to indent scope bottom' })
  H.map('o', maps.object_scope, '<Cmd>lua Grappler.textobject(false)<CR>', { desc = 'Object scope' })
  H.map('o', maps.object_scope_with_border, '<Cmd>lua Grappler.textobject(true)<CR>', { desc = 'Object scope with border' })
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

H.UR_ray = function(line, col)
	local target_line, target_col = line, col
	local original_line, original_col = line, col
	-- vim.notify("setup from line: " .. line)
	line = line - 1
	col = col + 1

	local max_col = vim.fn.winwidth(0) - 7
	-- local found_target = false;
	local not_done = true
	while not_done do
		-- vim.notify("loop: move up to line: " .. line)
		if line < 1 then
			target_line = 1 -- 1 indexed ughhh
			target_col = col -- TODO break
			not_done = false
		end
		if col > max_col then
			target_col = col
			target_line = line -- TODO break
			not_done = false
		end
		--                                              buf, start,  end, strict_indexing (whether out of bounds should be an error)

		if not_done == true then
			local line_content = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]
			if #line_content >= col then
				target_col = col
				target_line = line
				not_done = false
			end
		end
		line = line - 1
		col = col + 1
	end
	-- vim.notify(
	-- 	"found target (line:" .. target_line .. ",col:" .. target_col .. ") @ dist." .. (target_line - original_line)
	-- )
	return {
		found_target = true,
		target = { line = target_line, col = target_col },
		src = { line = original_line, col = original_col },
		direct = "TR",
	}
end

H.cast_ray = function(line, indent, direction, opts)
	local final_line, increment = 1, -1
	if direction == "down" then
		final_line, increment = vim.fn.line("$"), 1
	end

	local min_indent = math.huge
	for l = line, final_line, increment do
		local new_indent = H.get_line_indent(l + increment, opts)
		if new_indent < indent then
			return l, min_indent
		end
		if new_indent < min_indent then
			min_indent = new_indent
		end
	end

	return final_line, min_indent
end

H.scope_get_draw_indent = function(scope)
	return scope.border.indent or (scope.body.indent - 1)
end

H.scope_is_equal = function(scope_1, scope_2)
	if type(scope_1) ~= "table" or type(scope_2) ~= "table" then
		return false
	end

	return scope_1.buf_id == scope_2.buf_id
		and H.scope_get_draw_indent(scope_1) == H.scope_get_draw_indent(scope_2)
		and scope_1.body.top == scope_2.body.top
		and scope_1.body.bottom == scope_2.body.bottom
end

H.scope_has_intersect = function(scope_1, scope_2)
	if type(scope_1) ~= "table" or type(scope_2) ~= "table" then
		return false
	end
	if (scope_1.buf_id ~= scope_2.buf_id) or (H.scope_get_draw_indent(scope_1) ~= H.scope_get_draw_indent(scope_2)) then
		return false
	end

	local body_1, body_2 = scope_1.body, scope_2.body
	return (body_2.top <= body_1.top and body_1.top <= body_2.bottom)
		or (body_1.top <= body_2.top and body_2.top <= body_1.bottom)
end

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
		-- vim.notify("hook")
		virt_text = { { "X", hl_group } }
	else
		-- vim.notify("chain")
		virt_text = { { "╱", hl_group } }
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
				-- vim.notify("deleted extmark")
				vim.api.nvim_win_set_cursor(0, { line, col })
				return true
			end
			vim.notify("failed to del extmark w/ id (lemmeguess_nil_lol:" .. extmark_id .. ")")
			return false
		else
			-- return pcall(vim.api.nvim_buf_set_extmark, buf_id, H.ns_id, line - 1, 0, extmark_opts)
			local succ, id = pcall(vim.api.nvim_buf_set_extmark, buf_id, H.ns_id, line - 1, 0, extmark_opts)
			if succ then
				return id
			else
				vim.notify("failed to set extmark")
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
