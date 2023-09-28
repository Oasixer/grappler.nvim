local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
	return
end

--vim.keymap.del("n", "<leader>fn")
--
--
local id = vim.api.nvim_create_augroup("startup", {
	clear = false,
})

local persistbuffer = function(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	vim.fn.setbufvar(bufnr, "bufpersist", 1)
end

vim.api.nvim_create_autocmd({ "BufRead" }, {
	group = id,
	pattern = { "*" },
	callback = function()
		vim.api.nvim_create_autocmd({ "InsertEnter", "BufModifiedSet" }, {
			buffer = 0,
			once = true,
			callback = function()
				persistbuffer()
			end,
		})
	end,
})

local setup = {
	plugins = {
		marks = true, -- shows a list of your marks on ' and `
		registers = true, -- shows your registers on " in NORMAL or <C-r> in INSERT mode
		spelling = {
			enabled = true, -- enabling this will show WhichKey when pressing z= to select spelling suggestions
			suggestions = 20, -- how many suggestions should be shown in the list?
		},
		-- the presets plugin, adds help for a bunch of default keybindings in Neovim
		-- No actual key bindings are created
		presets = {
			operators = true, -- adds help for operators like d, y, ... and registers them for motion / text object completion
			motions = true, -- adds help for motions
			text_objects = true, -- help for text objects triggered after entering an operator
			windows = true, -- default bindings on <c-w>
			nav = true, -- misc bindings to work with windows
			z = true, -- bindings for folds, spelling and others prefixed with z
			g = true, -- bindings for prefixed with g
		},
	},
	-- add operators that will trigger motion and text object completion
	-- to enable all native operators, set the preset / operators plugin above
	operators = { gc = "Comments" },
	key_labels = {
		-- override the label used to display some keys. It doesn't effect WK in any other way.
		-- For example:
		-- ["<space>"] = "SPC",
		-- ["<CR>"] = "RET",
		-- ["<tab>"] = "TAB",
	},
	icons = {
		breadcrumb = "»", -- symbol used in the command line area that shows your active key combo
		separator = "➜", -- symbol used between a key and it's label
		group = "+", -- symbol prepended to a group
	},
	popup_mappings = {
		scroll_down = "<c-d>", -- binding to scroll down inside the popup
		scroll_up = "<c-u>", -- binding to scroll up inside the popup
	},
	window = {
		border = "rounded", -- none, single, double, shadow
		position = "bottom", -- bottom, top
		margin = { 1, 0, 1, 0 }, -- extra window margin [top, right, bottom, left]
		padding = { 0, 0, 0, 0 }, -- extra window padding [top, right, bottom, left]
		winblend = 0,
	},
	layout = {
		height = { min = 4, max = 20 }, -- min and max height of the columns
		width = { min = 20, max = 50 }, -- min and max width of the columns
		spacing = 1, -- spacing between columns
		align = "center", -- align columns left, center or right
	},
	ignore_missing = true, -- enable this to hide mappings for which you didn't specify a label
	hidden = { "<silent>", "<Cmd>", "<cmd>", "<CR>", "call", "lua", "^:", "^ " }, -- hide mapping boilerplate
	show_help = true, -- show help message on the command line when the popup is visible
	-- triggers = "auto", -- automatically setup triggers
	-- triggers = {"<leader>"} -- or specify a list manually
	triggers_blacklist = {
		-- list of mode / prefixes that should never be hooked by WhichKey
		-- this is mostly relevant for key maps that start with a native binding
		-- most people should not need to change this
		i = { "j", "k" },
		v = { "j", "k" },
	},
}

local opts = {
	mode = "n", -- NORMAL mode
	prefix = "<leader>",
	buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
	silent = true, -- use `silent` when creating keymaps
	noremap = true, -- use `noremap` when creating keymaps
	nowait = true, -- use `nowait` when creating keymaps
	--unique = true,
}

local noprefix_opts = {
	mode = "n", -- NORMAL mode
	prefix = "",
	buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
	silent = true, -- use `silent` when creating keymaps
	noremap = true, -- use `noremap` when creating keymaps
	nowait = true, -- use `nowait` when creating keymaps
}

local mappings = {
	w = {},

	b = {
		name = "Buffers",
		i = { "<Cmd>BufferLineCloseLeft<CR>", "[C]lose buffers left" },
		o = { "<Cmd>BufferLineCloseRight<CR>", "[C]lose buffers right" },
		-- currently duplicate of <Leader>O/I
		O = { "<Cmd>BufferLineMoveNext<CR>", "Move buf right" },
		-- currently duplicate of <Leader>O/I
		I = { "<Cmd>BufferLineMovePrev<CR>", "Move buf left" },
		c = { "<Cmd>BufferLinePickClose<CR>", "[C]lose buffer" },
		u = {
			function()
				local curbufnr = vim.api.nvim_get_current_buf()
				local buflist = vim.api.nvim_list_bufs()
				for _, bufnr in ipairs(buflist) do
					if
						vim.bo[bufnr].buflisted
						and bufnr ~= curbufnr
						and (vim.fn.getbufvar(bufnr, "bufpersist") ~= 1)
					then
						vim.cmd("bd " .. tostring(bufnr))
					end
				end
			end,
			"Close unused buffers",
		},
		[" "] = { "<Cmd>BufferLinePick<CR>", "Pick buffer" },
		b = { "<Cmd>BufferLinePick<CR>", "Pick buffer" },
		f = { "<Cmd>Telescope buffers<CR>", "[F]ind buffers" },
		p = { "<Cmd>BufferLineTogglePin<CR>", "Toggle [p]in" },
		-- last arg of go_to_buffer is 'absolute' (bool),
		-- where relative(false) means relative to visible bufferline entries
		["0"] = { "<Cmd>lua require('bufferline').go_to_buffer(1, true)<cr>", "Go to first buffer" },
		["$"] = { "<Cmd>lua require('bufferline').go_to_buffer(-1, true)<cr>", "Go to last buffer" },
		-- t = { ":NeoTreeFocus<CR>>", "Neotree focus buffs" },
	},
	--	["b"] = { "<Cmd>lua require('user.bfs').open()<CR>", "Buffers" },
	--	["e"] = { "<Cmd>Neotree toggle<CR>", "Explorer" },
	q = { '<Cmd>lua require("user.functions").smart_quit()<CR>', "Quit" },
	--	["c"] = { "<Cmd>Bdelete!<CR>", "Close Buffer" },
	--	["P"] = { "<Cmd>lua require('telescope').extensions.projects.projects()<CR>", "Projects" },
	--	["gy"] = "Open code in Browser",
	-- ["."] = "Goto next harpoon",
	-- [","] = "Goto next harpoon",

	--	u = {
	--		name = "TodoComments",
	--		["t"] = { "<Cmd>TodoTelescope<CR>", "Show Comments" },
	--		["q"] = { "<Cmd>TodoQuickFix<CR>", "Quick Fix" },
	--		["l"] = { "<Cmd>TodoLocList<CR>", "List Comments" },
	--	},

	--	B = {
	--		name = "Bookmarks",
	--		a = { "<Cmd>silent BookmarkAnnotate<CR>", "Annotate" },
	--		c = { "<Cmd>silent BookmarkClear<CR>", "Clear" },
	--		t = { "<Cmd>silent BookmarkToggle<CR>", "Toggle" },
	--		m = { '<Cmd>lua require("harpoon.mark").add_file()<CR>', "Harpoon" },
	--		n = { '<Cmd>lua require("harpoon.ui").toggle_quick_menu()<CR>', "Harpoon Toggle" },
	--		l = { "<Cmd>lua require('user.bfs').open()<CR>", "Buffers" },
	--		j = { "<Cmd>silent BookmarkNext<CR>", "Next" },
	--		s = { "<Cmd>Telescope harpoon marks<CR>", "Search Files" },
	--		k = { "<Cmd>silent BookmarkPrev<CR>", "Prev" },
	--		S = { "<Cmd>silent BookmarkShowAll<CR>", "Prev" },
	--		x = { "<Cmd>BookmarkClearAll<CR>", "Clear All" },
	--	},
	--
	l = {
		name = "l[a]zy/l[e]etcode",
		a = {
			name = "l[a]zy",
			c = { "<Cmd>Lazy check<CR>", "Check" },
			C = { "<Cmd>Lazy clean<CR>", "Clean" },
			i = { "<Cmd>Lazy install<CR>", "Install" },
			s = { "<Cmd>Lazy sync<CR>", "Sync" },
			u = { "<Cmd>Lazy update<CR>", "Update" },
			r = { "<Cmd>Lazy restore<CR>", "Restore" },
			l = { "<Cmd>Lazy<CR>", "Lazy" },
		},
		e = {
			name = "l[e]etcode",
			l = { "<Cmd>LeetCodeList<CR>", "[l]ist" },
			t = { "<Cmd>LeetCodeTest<CR>", "[t]test" },
			s = { "<Cmd>LeetCodeSubmit<CR>", "[s]ubmit" },
			S = { "<Cmd>LeetCodeSignIn<CR>", "[S]ign in" },
		},
	},

	["0"] = {
		name = "Options",
		w = { '<Cmd>lua require("user.functions").toggle_option("wrap")<CR>', "Wrap" },
		W = { '<Cmd>lua require("user.functions").toggle_option("linebreak")<CR>', "Wrap words instead of chars" },
		r = { '<Cmd>lua require("user.functions").toggle_option("relativenumber")<CR>', "Relative numbers" },
		l = { '<Cmd>lua require("user.functions").toggle_option("cursorline")<CR>', "Cursorline" },
		s = { '<Cmd>lua require("user.functions").toggle_option("spell")<CR>', "Spell" },
		t = { '<Cmd>lua require("user.functions").toggle_tabline()<CR>', "Tabline" },
	},

	s = {
		name = "Session",
		s = { "<Cmd>SaveSession<CR>", "Save" },
		r = { "<Cmd>RestoreSession<CR>", "Restore" },
		x = { "<Cmd>DeleteSession<CR>", "Delete" },
		f = { "<Cmd>Autosession search<CR>", "Find" },
		d = { "<Cmd>Autosession delete<CR>", "Find Delete" },
	},

	--	r = {
	--		name = "Replace",
	--		r = { "<Cmd>lua require('spectre').open()<CR>", "Replace" },
	--		w = { "<Cmd>lua require('spectre').open_visual({select_word=true})<CR>", "Replace Word" },
	--		f = { "<Cmd>lua require('spectre').open_file_search()<CR>", "Replace Buffer" },
	--	},
	--

	f = {
		name = "Find (Telescope)",
		p = { "<Cmd>lua require('telescope').load_extension('command_palette')<CR>", "Palette" },
		C = { "<Cmd>Telescope colorscheme<CR>", "[C]olorscheme" },
		f = { "<Cmd>Telescope find_files<CR>", "[F]ile" },
		[" "] = { "<Cmd>Telescope live_grep theme=ivy<CR>", "Live grep (find text)" },
		b = { "<Cmd>Telescope buffers<CR>", "Buffers" },
		t = {
			-- "<Cmd>lua require('telescope').extensions.live_grep_args.live_grep_args(require('telescope.themes').get_dropdown({ winblend = 10 }))<CR>",
			"<Cmd>lua require('telescope').extensions.live_grep_args.live_grep_args(require('telescope.themes').get_dropdown())<CR>",
			"Live grep raw",
		},
		-- B = { "<Cmd>Telescope git_branches<CR>", "checkout [B]ranch" },
		s = { "<Cmd>Telescope grep_string theme=ivy<CR>", "Find String" },
		h = { "<Cmd>Telescope harpoon marks<CR>", "Harpoon files" },
		H = { "<Cmd>Telescope help_tags<CR>", "Help" },
		X = { "<Cmd>Telescope highlights<CR>", "Highlights" },
		i = { "<Cmd>lua require('telescope').extensions.media_files.media_files()<CR>", "Media" },
		l = { "<Cmd>Telescope resume<CR>", "Last Search" },
		M = { "<Cmd>Telescope man_pages<CR>", "Man Pages" },
		r = { "<Cmd>Telescope oldfiles<CR>", "Recent File" },
		R = { "<Cmd>Telescope registers<CR>", "Registers" },
		k = { "<Cmd>Telescope keymaps<CR>", "Keymaps" },
		c = { "<Cmd>Telescope commands<CR>", "Commands" },
		n = { "<Cmd>Telescope notify<CR>", "Show notifications" },
		g = {
			name = "Git (Telescope status(files), branches, commits)",
			s = { "<Cmd>Telescope git_status<CR>", "Telescope git_status -> Open changed files" },
			b = { "<Cmd>Telescope git_branches<CR>", "Telescope git_branches -> Checkout branch" },
			c = { "<Cmd>Telescope git_commits<CR>", "Telescope git_commits" },
		},
	},
	-- l = {
	--   name = "LSP",
	--   g = {
	--     name = "Goto",
	--     [" "] = { "<Cmd>Lspsaga goto_definition<CR>", "Goto definition" },
	--     t = { "<Cmd>Lspsaga goto_type_definition<CR>", "Goto type definition" },
	--     r = { "<Cmd>Telescope lsp_references<CR>", "Telescope references" },
	--     -- e = { "<Cmd>lua vim.lsp.buf.declaration()<CR>", "Goto declaration" },
	--     -- i = { "<Cmd>Telescope lsp_implementations<CR>", "Telescope implementations" },
	--   },
	--   p = {
	--     name = "Peek",
	--     [" "] = { "<Cmd>Lspsaga peek_definition<CR>", "Peek definition" },
	--     t = { "<Cmd>Lspsaga peek_type_definition<CR>", "Peek type definition" },
	--     -- i = { "<Cmd>Telescope lsp_implementations<CR>", "Telescope implementations" },
	--   },
	--   d = {
	--     name = "Diagnostics",
	--     h = { '<Cmd>lua require("user.functions").hide_diagnostics()<CR>', "Hide Diagnostics" },
	--     s = { '<Cmd>lua require("user.functions").show_diagnostics()<CR>', "Show Diagnostics" },
	--     t = { '<Cmd>lua require("user.functions").toggle_diagnostics()<CR>', "Toggle Diagnostics" },
	--     n = { "<Cmd>Lspsaga diagnostic_jump_next<CR>", "Jump to next diagnostic" },
	--     p = { "<Cmd>Lspsaga diagnostic_jump_prev<CR>", "Jump to prev diagnostic" },
	--     f = { "<Cmd>Telescope diagnostics<CR>", "Telescope diagnostics" },
	--     l = { "<Cmd>Lspsaga show_line_diagnostics<CR>", "Show line diagnostics" },
	--   },
	--   f = {
	--     name = "Telescope",
	--     r = { "<Cmd>Telescope lsp_references<CR>", "Telescope references" },
	--     [" "] = { "<Cmd>Telescope lsp_definitions<CR>", "Telescope definitions" },
	--     i = { "<Cmd>Telescope lsp_implementations<CR>", "Telescope implementations" },
	--   },
	--   r = { "<Cmd>Telescope lsp_references<CR>", "Telescope references" },
	--   D = {
	--     name = "Documentation",
	--     h = { "<Cmd>lua vim.lsp.buf.hover()<CR>", "Hover (floating LSP info, usually documentation)" },
	--   },
	--   -- ["gd"] = { "<Cmd>Lspsaga peek_definition<CR>", "peek definition" },
	--   -- ["Df"] = { "<Cmd>lua vim.diagnostic.open_float()<CR>", "Floating " },
	--
	--   ["R"] = { "<Cmd>lua vim.lsp.buf.rename()<CR>", "Rename" },
	--   --["u"] = { "<Cmd>TroubleToggle lsp_references<CR>", "References" },
	--   -- diagnostics
	--   --w = { "<Cmd>Telescope lsp_workspace_diagnostics<CR>", "Workspace Diagnostics" },
	--   --t = { '<Cmd>lua require("user.functions").toggle_diagnostics()<CR>', "Toggle Diagnostics" },
	--   --n = { "<Cmd>Lspsaga diagnostic_jump_next<CR>", "next diagnostic" },
	--   -- keymap.set("n", "[d", "<Cmd>Lspsaga diagnostic_jump_prev<CR>", opts) -- jump to previous diagnostic in buffer
	--   -- keymap.set("n", "]d", "<Cmd>Lspsaga diagnostic_jump_next<CR>", opts) -- jump to next diagnostic in buffer
	-- },
	a = {
		name = "Trouble",
		t = { "<Cmd>TroubleToggle workspace_diagnostics<CR>", "TroubleToggle workspace_diagnostics" },
		r = { "<Cmd>TroubleToggle lsp_references<CR>", "References" },
	},
	t = {
		name = "Tab",
		o = { "<Cmd>tabnext<CR>", "Next tab" },
		i = { "<Cmd>tabprev<CR>", "Prev tab" },
		l = { "<Cmd>tabnew<CR>", "New tab right (like C-w,l in zellij)" },
		h = { "<Cmd>-tabnew<CR>", "New tab left (like C-w,h in zellij)" },
		n = { "<Cmd>tabnew<CR>", "[Deprecated] New tab right" },
	},
	T = {
		name = "Treesitter",
		h = { "<Cmd>TSHighlightCapturesUnderCursor<CR>", "Highlight" },
		p = { "<Cmd>TSPlaygroundToggle<CR>", "Playground" },
		r = { "<Cmd>TSToggle rainbow<CR>", "Rainbow" },
	},
	-- autoformat
	--f = { "<Cmd>lua vim.lsp.buf.format({ async = true })<CR>", "Format" },
	--F = { "<Cmd>LspToggleAutoFormat<CR>", "Toggle Autoformat" },
	--i = { "<Cmd>LspInfo<CR>", "Info" },
	--
	-- other
	--h = { "<Cmd>IlluminationToggle<CR>", "Toggle Doc HL" }, -- not installed
	--I = { "<Cmd>LspInstallInfo<CR>", "Installer Info" },
	--j = {
	--  "<Cmd>lua vim.diagnostic.goto_next({buffer=0})<CR>",
	--  "Next Diagnostic",
	--},
	--k = {
	--  "<Cmd>lua vim.diagnostic.goto_prev({buffer=0})<CR>",
	--  "Prev Diagnostic",
	--},
	--l = { "<Cmd>lua vim.lsp.codelens.run()<CR>", "CodeLens Action" },
	--q = { "<Cmd>lua vim.lsp.diagnostic.set_loclist()<CR>", "Quickfix" },
	--s = { "<Cmd>Telescope lsp_document_symbols<CR>", "Document Symbols" }, -- list of symbols in document
	--S = {
	--  "<Cmd>Telescope lsp_dynamic_workspace_symbols<CR>",
	--  "Workspace Symbols",
	--}, -- idk, seems broken
	--u = { "<Cmd>LuaSnipUnlinkCurrent<CR>", "Unlink Snippet" },

	--	S = {
	--		name = "SnipRun",
	--		c = { "<Cmd>SnipClose<CR>", "Close" },
	--		f = { "<Cmd>%SnipRun<CR>", "Run File" },
	--		i = { "<Cmd>SnipInfo<CR>", "Info" },
	--		m = { "<Cmd>SnipReplMemoryClean<CR>", "Mem Clean" },
	--		r = { "<Cmd>SnipReset<CR>", "Reset" },
	--		t = { "<Cmd>SnipRunToggle<CR>", "Toggle" },
	--		x = { "<Cmd>SnipTerminate<CR>", "Terminate" },
	--	},
	--
	-- t = {
	-- 	name = "Terminal",
	--
	-- vim.keymap.set('t', '<Esc>', '<C-\\><C-n><Cmd>lua require("FTerm").toggle()<CR>')
	--		["1"] = { ":1ToggleTerm<CR>", "1" },
	--		["2"] = { ":2ToggleTerm<CR>", "2" },
	--		["3"] = { ":3ToggleTerm<CR>", "3" },
	--		["4"] = { ":4ToggleTerm<CR>", "4" },
	--		n = { "<Cmd>lua _NODE_TOGGLE()<CR>", "Node" },
	--		u = { "<Cmd>lua _NCDU_TOGGLE()<CR>", "NCDU" },
	--		t = { "<Cmd>lua _HTOP_TOGGLE()<CR>", "Htop" },
	--		p = { "<Cmd>lua _PYTHON_TOGGLE()<CR>", "Python" },
	--		f = { "<Cmd>ToggleTerm direction=float<CR>", "Float" },
	--		h = { "<Cmd>ToggleTerm size=10 direction=horizontal<CR>", "Horizontal" },
	--		v = { "<Cmd>ToggleTerm size=80 direction=vertical<CR>", "Vertical" },
	--	},
	--
	--
	g = {
		name = "Git",
		--		g = { "<Cmd>lua _LAZYGIT_TOGGLE()<CR>", "Lazygit" },
		j = { "<Cmd>lua require 'gitsigns'.next_hunk()<CR>", "Next Hunk" },
		k = { "<Cmd>lua require 'gitsigns'.prev_hunk()<CR>", "Prev Hunk" },
		b = { "<Cmd>lua require 'gitsigns'.toggle_current_line_blame()<CR>", "Toggle current line blame" },
		B = { "<Cmd>lua require 'gitsigns'.blame_line{full=true}<CR>", "Show current line blame" },
		f = {
			name = "Telescope",
			s = { "<Cmd>Telescope git_status<CR>", "Telescope git_status -> Open changed files" },
			b = { "<Cmd>Telescope git_branches<CR>", "Telescope git_branches -> Checkout branch" },
			c = { "<Cmd>Telescope git_commits<CR>", "Telescope git_commits" },
		},
		r = { "<Cmd>lua require 'gitsigns'.reset_buffer()<CR>", "Reset Buffer" },
		d = {
			name = "Diff",
			h = { "<Cmd>lua require('gitsigns').diffthis('HEAD')<CR>'", "Diff vs HEAD" },
			["~"] = { "<Cmd>lua require('gitsigns').diffthis('~')<CR>'", "Diff vs ~ (= commit before HEAD)" },
		},
		h = {
			name = "Hunk (stage or reset)",
			s = { "<Cmd>lua require 'gitsigns'.stage_hunk()<CR>", "Stage Hunk" },
			r = { "<Cmd>lua require 'gitsigns'.reset_hunk()<CR>", "Reset Hunk" },
		},
	},
	--		p = { "<Cmd>lua require 'gitsigns'.preview_hunk()<CR>", "Preview Hunk" },
	--		R = { "<Cmd>lua require 'gitsigns'.reset_buffer()<CR>", "Reset Buffer" },
	--		u = {
	--			"<Cmd>lua require 'gitsigns'.undo_stage_hunk()<CR>",
	--			"Undo Stage Hunk",
	--		},
	--		d = {
	--			"<Cmd>Gitsigns diffthis HEAD<CR>",
	--			"Diff",
	--		},
	--
	--		G = {
	--			name = "Gist",
	--			a = { "<Cmd>Gist -b -a<CR>", "Create Anon" },
	--			d = { "<Cmd>Gist -d<CR>", "Delete" },
	--			f = { "<Cmd>Gist -f<CR>", "Fork" },
	--			g = { "<Cmd>Gist -b<CR>", "Create" },
	--			l = { "<Cmd>Gist -l<CR>", "List" },
	--			p = { "<Cmd>Gist -b -p<CR>", "Create Private" },
	--		},
	--	},
	--
	-- keymap.set("n", "gf", "<Cmd>Lspsaga lsp_finder<CR>", opts) -- show definition, references
	-- keymap.set("n", "gD", "<Cmd>lua vim.lsp.buf.declaration()<CR>", opts) -- got to declaration
	-- keymap.set("n", "gd", "<Cmd>Lspsaga peek_definition<CR>", opts) -- see definition and make edits in window
	-- keymap.set("n", "gi", "<Cmd>lua vim.lsp.buf.implementation()<CR>", opts) -- go to implementation
	-- keymap.set("n", "<leader>a", "<Cmd>Lspsaga code_action<CR>", opts) -- see available code actions
	-- keymap.set("n", "<leader>rn", "<Cmd>Lspsaga rename<CR>", opts) -- smart rename
	-- keymap.set("n", "<leader>d", "<Cmd>Lspsaga show_line_diagnostics<CR>", opts) -- show  diagnostics for line
	-- keymap.set("n", "<leader>d", "<Cmd>Lspsaga show_cursor_diagnostics<CR>", opts) -- show diagnostics for cursor
	-- keymap.set("n", "K", "<Cmd>Lspsaga hover_doc<CR>", opts) -- show documentation for what is under cursor
	-- keymap.set("n", "<leader>o", "<Cmd>LSoutlineToggle<CR>", opts) -- see outline on right hand side

	-- a = { "<Cmd>lua vim.lsp.buf.code_action()<CR>", "Code Action" }, -- for suggested actions like vscode to fix a diagnostic
	--                                                                   -- possibly also includes refactors??
	-- d = { "<Cmd>Telescope lsp_definitions<CR>" },
	-- keymap.set("n", "gl", "<Cmd>lua vim.diagnostic.open_float()<CR>", opts) -- go to implementation
	--
	--
	["/"] = { "<Plug>(comment_toggle_linewise_current)", "Comment" },
	y = { '"+y', "Yank Clipboard" },
	Y = { '"+y$', "Yank Clipboard to EOL" },
	p = { '"+p', "Put Clipboard" },
	P = { '"+P', "Put Clipboard" },
	o = { "<Cmd>BufferLineCycleNext<CR>", "Next buf" },
	i = { "<Cmd>BufferLineCyclePrev<CR>", "Prev buf" },
	-- currently duplicate of <Leader>bO/I
	O = { "<Cmd>BufferLineMoveNext<CR>", "Move buf right" },
	-- currently duplicate of <Leader>bO/I
	I = { "<Cmd>BufferLineMovePrev<CR>", "Move buf left" },

	j = { "<Cmd>echo 'moved cmd'<CR>", "moved cmd" },
	k = { "<Cmd>echo 'moved cmd'<CR>", "moved cmd" },
	-- j = { "o<esc>", "Blank line above" },
	-- k = { "O<esc>", "Blank line below" },
	[","] = {
		name = "Config / dotfiles / etc (TODO Eventually replace w bookmarks)",
		o = {
			"<Cmd>edit ~/bndx/2b/.obsidian.vimrc<CR>",
			"Obsidian.vimrc",
		},
		n = {
			v = { "<Cmd>edit ~/bndx/dotfiles/nvim/lua/plugins/init.lua<CR>", "Vim" },
			t = { "<Cmd>edit ~/bndx/dotfiles/nvim/lua/plugins/configs/neo-tree.lua<CR>", "NeoTree" },
		},
		c = { "<Cmd>edit ~/bndx/dotfiles/nvim/lua/plugins/configs/cmp.lua<CR>", "Cmp" },
		w = {
			name = "[we]zterm, [wh]ichkey",
			e = { "<Cmd>edit ~/bndx/dotfiles/wezterm/wezterm.lua<CR>", "[We]zterm" },
			h = { "<Cmd>edit ~/bndx/dotfiles/nvim/lua/plugins/configs/whichkey.lua<CR>", "[wh]ichKey" },
		},
		t = {
			name = "[te]lescope, [tri]dactyl, [tro]uble",
			e = { "<Cmd>edit ~/bndx/dotfiles/nvim/lua/plugins/configs/telescope.lua<CR>", "[te]lescope" },
			r = {
				name = "[tri]dactyl, [tro]uble",
				i = { "<Cmd>edit ~/bndx/dotfiles/tridactyl/tridactylrc<CR>", "[tri]dactyl" },
				o = { "<Cmd>edit ~/bndx/dotfiles/nvim/lua/plugins/configs/trouble.lua<CR>", "[tro]uble" },
			},
		},
		l = {
			name = "[la]zy, [ls]p, [lo]cal/share",
			s = { "<Cmd>edit ~/bndx/dotfiles/nvim/lua/plugins/configs/lsp/lspconfig.lua<CR>", "[ls]p" },
			a = { "<Cmd>edit ~/bndx/dotfiles/nvim/lua/plugins/init.lua<CR>", "[la]zy" },
			o = { "<Cmd>edit ~/.local/share/nvim/lazy<CR>", "[lo]" },
		},
		s = {
			name = "[s]hare",
			{ "<Cmd>edit ~/.local/share/nvim/lazy<CR>", "[s]hare" },
		},
		z = { "<Cmd>edit ~/bndx/dotfiles/zellij/config.kdl<CR>", "Zellij" },
		p = { "<Cmd>edit ~/bndx/install_scripts/configure_popos.sh<CR>", "PopOS" },
		f = {
			name = "[fi]refox, [fo]rks, [fu]nctions",
			i = { "<Cmd>edit ~/.mozilla/firefox/o7img99m.default-release/chrome/userChrome.orig.css<CR>", "[fi]refox" },
			o = { "<Cmd>edit ~/forks/plugins/lspsaga.nvim/README.md<CR>", "[fo]rks" },
			u = { "<Cmd>edit ~/bndx/dotfiles/nvim/lua/user/functions.lua<CR>", "[fu]nctions" },
		},
		i = { "<Cmd>edit ~/bndx/install_scripts/install_forks.sh<CR>", "install scripts" },
		r = { "<Cmd>edit ~/bndx/dotfiles/nvim/lua/plugins/configs/ranger.lua<CR>", "ranger.nvim" },
	},
}

local topts = {
	mode = "t", -- TERMINAL mode
	prefix = "<leader>",
	buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
	silent = true, -- use `silent` when creating keymaps
	noremap = true, -- use `noremap` when creating keymaps
	nowait = true, -- use `nowait` when creating keymaps
}
local tmappings = {
	["/"] = { "<Plug>(comment_toggle_linewise_visual)", "Comment toggle linewise (visual)" },
	s = { "<Esc><Cmd>'<,'>SnipRun<CR>", "Run range" },
	y = { '"+y', "Yank to clipboard" },
	p = { '"+p', "Put from clipboard" },
}

local vopts = {
	mode = "v", -- VISUAL mode
	prefix = "<leader>",
	buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
	silent = true, -- use `silent` when creating keymaps
	noremap = true, -- use `noremap` when creating keymaps
	nowait = true, -- use `nowait` when creating keymaps
}

local noprefix_vis_opts = {
	mode = "v", -- NORMAL mode
	prefix = "",
	buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
	silent = true, -- use `silent` when creating keymaps
	noremap = true, -- use `noremap` when creating keymaps
	nowait = true, -- use `nowait` when creating keymaps
}
local vmappings = {
	["/"] = { "<Plug>(comment_toggle_linewise_visual)", "Comment toggle linewise (visual)" },
	s = { "<Esc><Cmd>'<,'>SnipRun<CR>", "Run range" },
	y = { '"+y', "Yank to clipboard" },
	p = { '"+p', "Put from clipboard" },
	L = { ">>", "Indent" },
	H = { "<<", "Deindent" },
	g = {
		name = "Git",
		s = { "<Cmd>lua require 'gitsigns'.stage_hunk()<CR>", "Stage Hunk" },
		r = { "<Cmd>lua require 'gitsigns'.reset_hunk()<CR>", "Reset Hunk" },
	},
}

--disable default macro bc it conflicts too easily with q for quit in various dialogs" },
-- and im using for debug
vim.keymap.set("n", "q", "<Nop>")
-- vim.keymap.set("n", "'", "<Nop>")

local noprefix_norm = {
	["<F1>"] = { "<Cmd>Neotree toggle filesystem position=left reveal=true<CR>", "Nerdtree toggle" },
	-- ["<C-n>"] = { "<Cmd>Neotree toggle filesystem position=left reveal=true<CR>", "Nerdtree toggle" },
	-- Q = { "q", "macro" },
	Q = { "<Cmd>Neotree toggle filesystem position=float reveal=true<CR>", "Nerdtree toggle float" },
	d = { -- OG word motion shit dso (yso below)
		s = {
			o = {
				function()
					vim.api.nvim_feedkeys("mrbhxelx`rh", "n", false)
				end,
				"dso = delete anything surrounding the OG word so (camelCaseWord) -> camelCaseWord",
			},
			-- w = {
			--   function()
			--     vim.api.nvim_feedkeys("mrbhxelx`r", "n", false)
			--   end,
			--   "dsw = EXACTLY SAME AS dso because if it has another char around it, its not a camelCaseWord anyway",
			-- },
		},
	},
	y = { -- OG word motion shit: yso (see dso above)
		s = {
			o = {
				function()
					-- vim.notify("hi")
					local chr = vim.fn.nr2char(vim.fn.getchar())
					local left_chr = chr
					local right_chr = chr
					if chr == "}" or chr == "{" then
						left_chr = "{"
						right_chr = "{"
					-- return "viws" .. "{" .. "}" .. "<esc>P"
					elseif chr == ")" or chr == "(" then
						left_chr = "("
						right_chr = ")"
					-- return "viws" .. "(" .. ")" .. "<esc>P"
					elseif chr == ">" or chr == "<" then
						left_chr = "<"
						right_chr = ">"
					-- return "viws" .. "<" .. ">" .. "<esc>P"
					elseif chr == "]" or chr == "[" then
						left_chr = "["
						right_chr = "]"
						-- return "viws" .. "[" .. "]" .. "<esc>P"
					end
					vim.api.nvim_feedkeys("mrbi" .. left_chr .. "" .. "lea" .. right_chr .. "`rl", "n", false)
				end,
				"replace",
			},
		},
	},

	g = {
		name = "g in normal mode, currently disabled",
		["d"] = { "<Nop>", "gd is disabled" },
		[";"] = {
			"<Cmd>lua require('user.functions').goto_last_edit_on_diff_line()<CR>",
			"goto_last_edit_on_diff_line",
		},
	}, -- this works!
	["<Up>"] = { "5k", "move 10" },
	["<Right>"] = { "4l", "move right scope" },
	["<Down>"] = { "5j", "move 10" },
	["<Left>"] = { "<Cmd>lua MiniIndentscope.operator('left', false)<CR>", "move left scope" },
	-- L = { ">>", "Indent" },
	-- H = { "<<", "Deindent" },
	-- L = { "^", "Move right (would be nice to go to next scope level but eh)" },
	["<Esc>"] = { "<Cmd>nohl<CR>", "Unhighlight search results" },

	["U"] = {
		function()
			vim.notify("U was pressed, caps lock on? 🤦🤦🤦")
		end,
		"uppercase u no thank you",
	},

	-- !!!!!!!!!!!!r;r;r;!!!!!!!!!!! CR is available!!
	-- ["<CR>"] = {
	--   "<Plug>(easymotion-repeat)",
	--   "repeat last easymotion motion",
	-- },

	-- ["t"] = {
	-- t = { "t", "normal t" },
	-- s = { "<Plug>(easymotion-bd-t)", "easymotion t search (bidirectional t/T, multiline)" },
	-- },

	["'"] = {
		name = "Easymotion",
		d = { -- not rlly easymotion just OG word motion shit
			s = {
				o = {
					function()
						vim.api.nvim_feedkeys("mrbhxelx`r", "n", false)
					end,
					"dso = delete anything surrounding the OG word so (camelCaseWord) -> camelCaseWord",
				},
				-- w = {
				--   function()
				--     vim.api.nvim_feedkeys("mrbhxelx`r", "n", false)
				--   end,
				--   "dsw = EXACTLY SAME AS dso because if it has another char around it, its not a camelCaseWord anyway",
				-- },
			},
		},
		y = {
			s = {
				o = {
					function()
						-- vim.notify("hi")
						local chr = vim.fn.nr2char(vim.fn.getchar())
						local left_chr = chr
						local right_chr = chr
						if chr == "}" or chr == "{" then
							left_chr = "{"
							right_chr = "{"
						-- return "viws" .. "{" .. "}" .. "<esc>P"
						elseif chr == ")" or chr == "(" then
							left_chr = "("
							right_chr = ")"
						-- return "viws" .. "(" .. ")" .. "<esc>P"
						elseif chr == ">" or chr == "<" then
							left_chr = "<"
							right_chr = ">"
						-- return "viws" .. "<" .. ">" .. "<esc>P"
						elseif chr == "]" or chr == "[" then
							left_chr = "["
							right_chr = "]"
							-- return "viws" .. "[" .. "]" .. "<esc>P"
						end
						vim.api.nvim_feedkeys("mrbi" .. left_chr .. "" .. "lea" .. right_chr .. "`r", "n", false)
					end,
					"replace",
				},
			},
		},

		s = { "<Plug>(easymotion-s)", "easymotion search (bidirectional f/F, multiline)" },
		w = { "<Plug>(easymotion-bd-w)", "easymotion to beginning of word (bidirectional w/b, multiline)" },
		b = { "<Plug>(easymotion-bd-w)", "easymotion to beginning of word (bidirectional w/b, multiline)" },
		e = { "<Plug>(easymotion-bd-e)", "easymotion to end of word (bidirectional e/ge, multiline)" },
		j = { "<Plug>(easymotion-bd-jk)", "easymotion to end of word (bidirectional j/k, multiline)" },
		["/"] = { "<Plug>(easymotion-sn)", "search kinda like /" },
		["n"] = { "<Plug>(easymotion-next)", "easymotion next" },
		["N"] = { "<Plug>(easymotion-prev)", "easymotion next" },
	},

	[";"] = { -- TODO!!!!!!!!!!!! I REGRET THIS, MOVE TO IT <CR> IN NORMAL MODE??????????
		name = "Debug",
		[";"] = {
			";",
			"normal semicolon behavior",
		},
		-- h = { "<Cmd>RustHoverActions<CR>", "Hover actions" },
		b = { "<Cmd>lua require'dap'.toggle_breakpoint()<CR>", "Breakpoint" },
		[" "] = { "<Cmd>Neotree close<CR>:lua require'dap'.continue()<CR>", "Continue" },
		l = { "<Cmd>lua require'dap'.step_into()<CR>", "Into" },
		j = { "<Cmd>lua require'dap'.step_over()<CR>", "Over" },
		h = { "<Cmd>lua require'dap'.step_out()<CR>", "Out" },
		-- r = reload!  (for rust anyway)
		R = { "<Cmd>lua require'dap'.repl.toggle()<CR>", "Repl" },
		-- l = { "<Cmd>lua require'dap'.run_last()<CR>", "Last" },
		g = { "<Cmd>lua require'dap'.run_to_cursor()<CR>", "Run to cursor line" },
		t = { "<Cmd>Neotree close<CR>:lua require'dapui'.toggle()<CR>", "Toggle UI" },
		q = { "<Cmd>lua require'dap'.terminate()<CR>5<C-w>j:close<CR>:close<CR>", "Terminate debugging & close bs" },
		x = { "5<C-w>j:close<CR>:close<CR>", "Close debugger bs" },
	},

	z = {
		name = "zFold",
		z = { "zR", "unfold all" },
	},

	["<C-a>"] = {
		name = "Trouble",
		a = { "<Cmd>TroubleToggle<CR>", "Trouble Toggle" },
		["<C-a>"] = { "<Cmd>TroubleToggle<CR>", "Trouble Toggle" },
		t = { "<Cmd>TroubleToggle<CR>", "Trouble Toggle" },

		q = { "<Cmd>Trouble quickfix<CR>", "Trouble Quickfix" }, -- q
		w = { "<Cmd>Trouble workspace_diagnostics<CR>", "Trouble Workspace Diagnostics" },
		d = { "<Cmd>Trouble document_diagnostics<CR>", "Trouble Doc Diagnostics" },
		-- ["<Space>"] = { "<Cmd>Trouble lsp_definitions<CR>", "Trouble Definitions" }, -- d
	},

	s = {
		name = "Saga",
		gd = { "<Cmd>Lspsaga goto_definition<CR>", "Goto definition" },
		gt = { "<Cmd>Lspsaga goto_type_definition<CR>", "Goto type definition" },
		i = { "<Cmd>Telescope lsp_implementations<CR>", "Telescope implementations" },
		[" "] = { "<Cmd>Lspsaga peek_definition<CR>", "Peek definition" },
		f = { "<Cmd>Lspsaga lsp_finder<CR>", "Finder" },
		-- use r here for whichever references thing is preferred
		r = { "<Cmd>Telescope lsp_references<CR>", "Telescope references" },
		R = { "<Cmd>Lspsaga rename<CR>", "Rename" },
		-- },
		-- e = { "<Cmd>lua vim.lsp.buf.declaration()<CR>", "Goto declaration" },
		-- i = { "<Cmd>Telescope lsp_implementations<CR>", "Telescope implementations" },
		n = { "<Cmd>Lspsaga diagnostic_jump_next<CR>", "Jump to next diagnostic" },
		p = { "<Cmd>Lspsaga diagnostic_jump_prev<CR>", "Jump to prev diagnostic" },

		d = {
			name = "Diagnostics",
			-- h = { '<Cmd>lua require("user.functions").hide_diagnostics()<CR>', "Hide Diagnostics" },
			-- s = { '<Cmd>lua require("user.functions").show_diagnostics()<CR>', "Show Diagnostics" },
			t = { '<Cmd>lua require("user.functions").toggle_diagnostics()<CR>', "Toggle Diagnostics" },
			f = { "<Cmd>Telescope diagnostics<CR>", "Telescope diagnostics" },
			l = { "<Cmd>Lspsaga show_line_diagnostics<CR>", "Show line diagnostics" },
		},
		["'"] = {
			name = "Documentation",
			h = { "<Cmd>lua vim.lsp.buf.hover()<CR>", "Hover (floating LSP info, usually documentation)" },
		},
		['"'] = {
			name = "Documentation",
			h = { "<Cmd>lua vim.lsp.buf.hover()<CR>", "Hover (floating LSP info, usually documentation)" },
		},
		h = {
			name = "Inlay Hints",
			e = { "<Cmd>RustSetInlayHints<CR>", "Enable inlay hints" },
			d = { "<Cmd>RustUnsetInlayHints<CR>", "Disable inlay hints" },
		},
		o = {
			"od08a<Space>kIljd$a", --d$:s/a/ /g<CR>",
			"newline match indent",
		},
	},

	-- ["<C-a>"] = { "<Cmd>TroubleToggle<CR>", "Trouble Toggle" },
	-- ["<C-p>"] = { "<Cmd>TroubleToggle<CR>", "Trouble Toggle" },
	-- ["<F1>"] = { "<Cmd>TroubleToggle<CR>", "Trouble" }, -- a
	-- ["<F10>"] = { "<Cmd>Trouble lsp_type_definitions<CR>", "Trouble" }, -- t
	-- ["<F4>"] = { "<Cmd>Trouble lsp_references<CR>", "Trouble" },

	-- [""]
	-- TODO: I desperately need a way to shift windows. use:
	-- https://github.com/sindrets/winshift.nvim ?
	["_"] = { "<C-w>w", "Previous window / focus foreground window" },
	["|"] = { "<C-w>w", "Previous window / focus foreground window" },
	["<C-w>"] = {
		name = "Window",
		-- v = { "<C-w>v", "Vertical Split" },
		-- h = { "<C-w>s", "Horizontal Split" },
		-- (this is C-w = if my font is being fancy and making a >= sign)
		s = { "<Cmd>lua require('user.functions').win_buf_swap()<CR>", "Swap last 2 windows" },
		e = { "<C-w>=", "Make Splits Equal" },
		c = { ":close<CR>", "Close Split" },
		m = { ":MaximizerToggle<CR>", "Toggle Maximizer" },
		p = { "<Cmd>wincmd w<CR>", "Focus floating window" },
		f = { "<Cmd>wincmd w<CR>", "Focus floating window" },
		o = { "<C-w>o", "Only (Close all other windows)" },

		k = { "<Cmd>new<CR>", "New split above" },
		j = { "<Cmd>set splitbelow<CR>:new<CR>:set nosplitbelow<CR>", "New split below" },
		l = { "<Cmd>set splitright<CR>:vnew<CR>:set nosplitright<CR>", "New split right" },
		h = { "<Cmd>vnew<CR>", "New split left" },
		["<C-h>"] = { "<Plug>ResizeWindowLeft<CR>", "Resize left" },
		["<C-j>"] = { "<Plug>ResizeWindowDown<CR>", "Resize down" },
		["<C-k>"] = { "<Plug>ResizeWindowUp<CR>", "Resize up" },
		["<C-l>"] = { "<Plug>ResizeWindowRight<CR>", "Resize right" },

		h_ = { "Note: h is mapped by vim_resizewindow" },
		j_ = { "Note: h is mapped by vim_resizewindow" },
		k_ = { "Note: h is mapped by vim_resizewindow" },
		l_ = { "Note: h is mapped by vim_resizewindow" },
	},
	--
	-- CONTROL the position :)
	["<C-S-h>"] = { "<C-w><lt>", "resize narrower" },
	["<C-S-l>"] = { "<C-w>>", "resize wider" },
	["<C-S-j>"] = { "<Cmd>res +1<CR>", "resize taller" },
	["<C-S-k>"] = { "<Cmd>res -1<CR>", "resize shorter" },

	["<A-8>"] = { "<C-j>", "C-j can be ambiguous at the terminal level (zellij shit the bed w/ it)", remap = true },
	-- spelling
	-- nnoremap <A-M> 8<C-w><lt>
	-- nnoremap <A-N> 8<C-w>>
	-- nnoremap <A--> :res -1<CR>
	-- nnoremap <A-=> :res +1<CR>
	-- nnoremap <A-_> :res -5<CR>
	-- nnoremap <A-+> :res +5<CR>
	["<A-S-n>"] = { '<cmd>lua require("harpoon.mark").add_file()<CR>', "[N]ew file mark" },
	["<A-S-m>"] = { '<cmd>lua require("harpoon.ui").toggle_quick_menu()<CR>', "Toggle harpoon [m]enu" },
	["<A-S-a>"] = { '<cmd>lua require("harpoon.ui").nav_file(1)<CR>', "File1" },
	["<A-S-s>"] = { '<cmd>lua require("harpoon.ui").nav_file(2)<CR>', "File2" },
	["<A-S-d>"] = { '<cmd>lua require("harpoon.ui").nav_file(3)<CR>', "File3" },
	["<A-S-f>"] = { '<cmd>lua require("harpoon.ui").nav_file(4)<CR>', "File4" },
	["<A-2>"] = { '<cmd>lua require("harpoon.ui").nav_next()<CR>', "Next" }, -- j
	["<A-3>"] = { '<cmd>lua require("harpoon.ui").nav_prev()<CR>', "Prev" }, -- k
	["<A-4>"] = { "<cmd>Telescope harpoon marks<CR>", "Prev" }, -- l

	["<F2>"] = { "<cmd>Lspsaga rename<CR>", "Rename" }, -- l

	["<C-c>"] = { "<Cmd>close<CR>", "Close", silent = true },

	-- q = {
	--   name = 'q = " = quote = registers :) ',
	--   -- TODO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1
	--   --
	--   --
	--   -- read dis shit
	--   -- https://www.baeldung.com/linux/vim-registers
	--   --
	--   --
	--   {
	--     r = { "<Cmd>lua require('user.functions').shift_registers()<CR>", "cycle registers" },
	--     q = { '"q', "qreg" },
	--     z = { '"z', "zreg" },
	--     f = { '"f', "freg" },
	--     ["0"] = { '"0', "0reg" }, -- default register
	--     ["1"] = { '"1', "1reg" },
	--     ["2"] = { '"2', "2reg" },
	--     ["3"] = { '"3', "3reg" },
	--     -- add missing numbers here
	--     ["7"] = { '"7', "7reg" },
	--     ["8"] = { '"8', "8reg" },
	--     ["9"] = { '"9', "9reg" },
	--
	--     ["a"] = { '"a', "areg" },
	--     -- add missing letters here
	--
	--     -- add the rest of the identifiers that are valid vim registers, ie:
	--     ["_"] = { '"_', "_reg" }, -- black hole register
	--   },
	-- },

	[","] = {
		name = "Add/del@EOL & file stuff",
		[","] = { "mbA,<Esc>`b", "Add comma to end of line" },
		['"'] = { 'mbA"<Esc>`b', 'Add " to end of line' },
		["."] = { "mbA.<Esc>`b", "Add . to end of line" },
		[";"] = { "mbA;<Esc>`b", "Add ; to end of line" },
		x = { "mbA<BS><Esc>`b", "Delete @ end of line" },
		u = { "u<C-o>", "Undo without moving" },

		f = { "mbo<Esc>0D`b", "Blank line below" },
		d = { "mbO<Esc>0D`b", "Blank line above" },

		c = { "<Cmd>tcd %:p:h<CR>", "CUR TAB: set cwd to cur window buffer parent" },
		l = { "<Cmd>lcd %:p:h<CR>", "CUR WINDOW: set cwd to cur window buffer parent" },
		-- this was on p and h but its just easier to hit a idk
		a = { "<Cmd>lua require('user.functions').cd_to_cwd_parent()<CR>", "CWD: cd .." },
		g = { "<Cmd>ProjectRoot<CR>", "Update project root using plugin" },
		m = { "<Cmd>ToggleManualProjectMode<CR>", "Toggle manual project mode" },

		r = { "<Cmd>e .<CR>", "Ranger ." },
		--
		-- todo have tools for changing nerdtree root, etc. here.
		--
		-- I would like better options than just NerdTreeReveal,
		-- but running that to reveal the parent of cur file works for now.
		n = { "<Cmd>NeoTreeReveal<CR>", "Reveal parent of cur buffer, in NeoTree" },
	},
}
local noprefix_vis = {
	-- ["<C-n>"] = { "<Cmd>Neotree toggle filesystem position=left reveal=true<CR>", "Nerdtree toggle" },
	["<C-n>"] = { "<Cmd>echo 'moved to <F1>'<CR>", "moved cmd" },
	["<F1>"] = { "<Cmd>Neotree toggle filesystem position=left reveal=true<CR>", "Nerdtree toggle" },
	["'"] = {
		name = "Easymotion",
		s = { "<Plug>(easymotion-s)", "easymotion search (bidirectional f/F, multiline)" },
		w = { "<Plug>(easymotion-bd-w)", "easymotion to beginning of word (bidirectional w/b, multiline)" },
		b = { "<Plug>(easymotion-bd-w)", "easymotion to beginning of word (bidirectional w/b, multiline)" },
		e = { "<Plug>(easymotion-bd-e)", "easymotion to end of word (bidirectional e/ge, multiline)" },
	},
}

which_key.setup(setup)
which_key.register(mappings, opts)
which_key.register(noprefix_norm, noprefix_opts)
which_key.register(vmappings, vopts)
which_key.register(noprefix_vis, noprefix_vis_opts)
