-- --- Generate linear progression
-- ---
-- ---@param opts __indentscope_animation_opts
-- ---
-- ---@return __indentscope_animation_return
-- Grappler.gen_animation.linear = function(opts)
-- 	return H.animation_arithmetic_powers(0, H.normalize_animation_opts(opts))
-- end
--
-- --- Generate quadratic progression
-- ---
-- ---@param opts __indentscope_animation_opts
-- ---
-- ---@return __indentscope_animation_return
-- Grappler.gen_animation.quadratic = function(opts)
-- 	return H.animation_arithmetic_powers(1, H.normalize_animation_opts(opts))
-- end
--
-- --- Generate cubic progression
-- ---
-- ---@param opts __indentscope_animation_opts
-- ---
-- ---@return __indentscope_animation_return
-- Grappler.gen_animation.cubic = function(opts)
-- 	return H.animation_arithmetic_powers(2, H.normalize_animation_opts(opts))
-- end
--
-- --- Generate quartic progression
-- ---
-- ---@param opts __indentscope_animation_opts
-- ---
-- ---@return __indentscope_animation_return
-- Grappler.gen_animation.quartic = function(opts)
-- 	return H.animation_arithmetic_powers(3, H.normalize_animation_opts(opts))
-- end
--
-- --- Generate exponential progression
-- ---
-- ---@param opts __indentscope_animation_opts
-- ---
-- ---@return __indentscope_animation_return
-- Grappler.gen_animation.exponential = function(opts)
-- 	return H.animation_geometrical_powers(H.normalize_animation_opts(opts))
-- end
--

-- if H.is_disabled() then
-- 	H.undraw_scope()
-- 	return
-- end
--
-- opts = opts or {}
-- local scope = Grappler.get_scope()
--
-- -- Make early return if nothing has to be done. Doing this before updating
-- -- event id allows to not interrupt ongoing animation.
-- if opts.lazy and H.current.draw_status ~= "none" and H.scope_is_equal(scope, H.current.scope) then
-- 	return
-- end
--
-- -- Account for current event
-- local local_event_id = H.current.event_id + 1
-- H.current.event_id = local_event_id
--
-- -- Compute drawing options for current event
-- local draw_opts = H.make_autodraw_opts(scope)
--
-- -- Allow delay
-- if draw_opts.delay > 0 then
-- 	H.undraw_scope(draw_opts)
-- end
--
-- -- Use `defer_fn()` even if `delay` is 0 to draw indicator only after all
-- -- events are processed (stops flickering)
-- vim.defer_fn(function()
-- 	if H.current.event_id ~= local_event_id then
-- 		return
-- 	end
--
-- 	H.undraw_scope(draw_opts)
--
-- 	H.current.scope = scope
-- 	H.draw_scope(scope, draw_opts)
-- end, draw_opts.delay)
-- end

--- Draw scope manually
---
--- Scope is visualized as a vertical line withing scope's body range at column
--- equal to border indent plus one (or body indent if border is absent).
--- Numbering starts from one.
---
---@param scope table|nil Scope. Default: output of |MiniIndentscope.get_scope|
---   with default arguments.
---@param opts table|nil Options. Currently supported:
---    - <animation_fun> - animation function for drawing. See
---      |MiniIndentscope-drawing| and |MiniIndentscope.gen_animation|.
---    - <priority> - priority number for visualization. See `priority` option
---      for |nvim_buf_set_extmark()|.
Grappler.draw = function(scope, opts)
	scope = scope or Grappler.get_scope()
	local config = H.get_config()
	local draw_opts = vim.tbl_deep_extend(
		"force",
		{ animation_fun = config.draw.animation, priority = config.draw.priority },
		opts or {}
	)

	H.undraw_scope()

	H.current.scope = scope
	H.draw_scope(scope, draw_opts)
end

-- Animations -----------------------------------------------------------------
--- Imitate common power easing function
---
--- Every step is preceeded by waiting time decreasing/increasing in power
--- series fashion (`d` is "delta", ensures total duration time):
--- - "in":  d*n^p; d*(n-1)^p; ... ; d*2^p;     d*1^p
--- - "out": d*1^p; d*2^p;     ... ; d*(n-1)^p; d*n^p
--- - "in-out": "in" until 0.5*n, "out" afterwards
---
--- This way it imitates `power + 1` common easing function because animation
--- progression behaves as sum of `power` elements.
---
---@param power number Power of series.
---@param opts table Options from `MiniIndentscope.gen_animation` entry.
---@private
-- H.animation_arithmetic_powers = function(power, opts)
-- 	-- Sum of first `n_steps` natural numbers raised to `power`
-- 	local arith_power_sum = ({
-- 		[0] = function(n_steps)
-- 			return n_steps
-- 		end,
-- 		[1] = function(n_steps)
-- 			return n_steps * (n_steps + 1) / 2
-- 		end,
-- 		[2] = function(n_steps)
-- 			return n_steps * (n_steps + 1) * (2 * n_steps + 1) / 6
-- 		end,
-- 		[3] = function(n_steps)
-- 			return n_steps ^ 2 * (n_steps + 1) ^ 2 / 4
-- 		end,
-- 	})[power]

-- Function which computes common delta so that overall duration will have
-- desired value (based on supplied `opts`)
-- local duration_unit, duration_value = opts.unit, opts.duration
-- local make_delta = function(n_steps, is_in_out)
-- 	local total_time = duration_unit == "total" and duration_value or (duration_value * n_steps)
-- 	local total_parts
-- 	if is_in_out then
-- 		-- Examples:
-- 		-- - n_steps=5: 3^d, 2^d, 1^d, 2^d, 3^d
-- 		-- - n_steps=6: 3^d, 2^d, 1^d, 1^d, 2^d, 3^d
-- 		total_parts = 2 * arith_power_sum(math.ceil(0.5 * n_steps)) - (n_steps % 2 == 1 and 1 or 0)
-- 	else
-- 		total_parts = arith_power_sum(n_steps)
-- 	end
-- 	return total_time / total_parts
-- end

-- 	return ({
-- 		["in"] = function(s, n)
-- 			return make_delta(n) * (n - s + 1) ^ power
-- 		end,
-- 		["out"] = function(s, n)
-- 			return make_delta(n) * s ^ power
-- 		end,
-- 		["in-out"] = function(s, n)
-- 			local n_half = math.ceil(0.5 * n)
-- 			local s_halved
-- 			if n % 2 == 0 then
-- 				s_halved = s <= n_half and (n_half - s + 1) or (s - n_half)
-- 			else
-- 				s_halved = s < n_half and (n_half - s + 1) or (s - n_half + 1)
-- 			end
-- 			return make_delta(n, true) * s_halved ^ power
-- 		end,
-- 		["none"] = function(s, n)
-- 			vim.notify("none, s:" .. s .. ",n:" .. n)
-- 			return make_delta(n) * (s - 1) -- Linear progression (no easing)
-- 		end,
-- 	})[opts.easing]
-- end

--- Imitate common exponential easing function
---
--- Every step is preceeded by waiting time decreasing/increasing in geometric
--- progression fashion (`d` is 'delta', ensures total duration time):
--- - 'in':  (d-1)*d^(n-1); (d-1)*d^(n-2); ...; (d-1)*d^1;     (d-1)*d^0
--- - 'out': (d-1)*d^0;     (d-1)*d^1;     ...; (d-1)*d^(n-2); (d-1)*d^(n-1)
--- - 'in-out': 'in' until 0.5*n, 'out' afterwards
---
---@param opts table Options from `MiniIndentscope.gen_animation` entry.
---@private
H.animation_geometrical_powers = function(opts)
	-- Function which computes common delta so that overall duration will have
	-- desired value (based on supplied `opts`)
	local duration_unit, duration_value = opts.unit, opts.duration
	local make_delta = function(n_steps, is_in_out)
		local total_time = duration_unit == "step" and (duration_value * n_steps) or duration_value
		-- Exact solution to avoid possible (bad) approximation
		if n_steps == 1 then
			return total_time + 1
		end
		if is_in_out then
			local n_half = math.ceil(0.5 * n_steps)
			-- Example for n_steps=6:
			-- Steps: (d-1)*d^2, (d-1)*d^1, (d-1)*d^0, (d-1)*d^0, (d-1)*d^1, (d-1)*d^2
			-- Sum: 2 * (d - 1) * (d^0 + d^1 + d^2) = 2 * (d^3 - 1)
			-- Solution: 2 * (d^3 - 1) = total_time =>
			--   d = math.pow(0.5 * total_time + 1, 1 / 3)
			--
			-- Example for n_steps=5:
			-- Steps: (d-1)*d^2, (d-1)*d^1, (d-1)*d^0, (d-1)*d^1, (d-1)*d^2
			-- Sum: 2 * (d - 1) * (d^0 + d^1 + d^2) - (d - 1) = 2 * (d^3 - 1) - (d - 1)
			-- Solution: 2 * (d^3 - 1) - (d - 1) = total_time =>
			--   As there is no general explicit solution, use approximation =>
			--   (Exact solution without `- (d-1)`):
			--     d_0 = math.pow(0.5 * total_time + 1, 1 / 3);
			--   (Correction by solving exactly withtou `- (d-1)` for
			--   `total_time_corr = total_time + (d_0 - 1)`):
			--     d_1 = math.pow(0.5 * total_time_corr + 1, 1 / 3)
			if n_steps % 2 == 1 then
				total_time = total_time + math.pow(0.5 * total_time + 1, 1 / n_half) - 1
			end
			return math.pow(0.5 * total_time + 1, 1 / n_half)
		end
		return math.pow(total_time + 1, 1 / n_steps)
	end

	return ({
		["in"] = function(s, n)
			local delta = make_delta(n)
			return (delta - 1) * delta ^ (n - s)
		end,
		["out"] = function(s, n)
			local delta = make_delta(n)
			return (delta - 1) * delta ^ (s - 1)
		end,
		["in-out"] = function(s, n)
			local n_half, delta = math.ceil(0.5 * n), make_delta(n, true)
			local s_halved
			if n % 2 == 0 then
				s_halved = s <= n_half and (n_half - s) or (s - n_half - 1)
			else
				s_halved = s < n_half and (n_half - s) or (s - n_half)
			end
			return (delta - 1) * delta ^ s_halved
		end,
	})[opts.easing]
end

H.normalize_animation_opts = function(x)
	x = vim.tbl_deep_extend("force", { easing = "in-out", duration = 20, unit = "step" }, x or {})

	if not vim.tbl_contains({ "in", "out", "in-out", "none" }, x.easing) then
		H.error([[In `gen_animation` option `easing` should be one of 'in', 'out', or 'in-out'.]])
	end

	if type(x.duration) ~= "number" or x.duration < 0 then
		H.error([[In `gen_animation` option `duration` should be a positive number.]])
	end

	if not vim.tbl_contains({ "total", "step" }, x.unit) then
		H.error([[In `gen_animation` option `unit` should be one of 'step' or 'total'.]])
	end

	return x
end

H.make_draw_function = function(indicator, opts)
	local extmark_opts = {
		hl_mode = "combine",
		priority = opts.priority,
		right_gravity = false,
		virt_text = indicator.virt_text,
		virt_text_win_col = indicator.virt_text_win_col,
		virt_text_pos = "overlay",
	}

	local current_event_id = opts.event_id

	return function(l)
		-- Don't draw if outdated
		if H.current.event_id ~= current_event_id and current_event_id ~= nil then
			return false
		end

		-- Don't draw if disabled
		if H.is_disabled() then
			return false
		end

		-- Don't put extmark outside of indicator range
		if not (indicator.top <= l and l <= indicator.bottom) then
			return true
		end

		return pcall(vim.api.nvim_buf_set_extmark, indicator.buf_id, H.ns_id, l - 1, 0, extmark_opts)
	end
end
