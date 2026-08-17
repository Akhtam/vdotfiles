-- lua/ak/plugins/blink.lua
--
-- Completion. Pinned to the 1.x line in plugins/init.lua — v2 is mid-rewrite
-- and needs a separate blink.lib plugin.
--
-- blink's defaults are good, so this file is mostly small deviations and the
-- reasoning for them. Options were checked against the v1.10.2 schema in
-- lua/blink/cmp/config/.

require("blink.cmp").setup({
	-- ── Keymap ───────────────────────────────────────────────────────────────
	-- 'default' keeps completion on Ctrl keys and leaves Tab and Enter alone:
	--   <C-space>  open menu / open docs      <C-y>  accept
	--   <C-n>/<C-p> or <Up>/<Down>  cycle     <C-e>  dismiss
	--   <C-k>      toggle signature help
	--
	-- Chosen over 'super-tab' and 'enter' because both overload a key that
	-- already means something, so menu visibility silently changes what a
	-- keystroke does — press Enter for a newline, get a completion. <C-y> only
	-- ever means accept.
	keymap = {
		preset = "default",

		["<A-k>"] = { "select_prev", "fallback" },
		["<A-j>"] = { "select_next", "fallback" },
		["<A-b>"] = { "scroll_documentation_up", "fallback" },
		["<A-f>"] = { "scroll_documentation_down", "fallback" },
		["<A-Space>"] = { "show", "show_documentation", "hide_documentation" },
		["<A-e>"] = { "hide", "fallback" },
		["<CR>"] = { "accept", "fallback" },
		-- Snippet navigation. Placed here rather than relying on a preset so that
		-- jumping between snippet placeholders doesn't collide with Tab-indent.
		["<C-l>"] = { "snippet_forward", "fallback" },
		["<C-h>"] = { "snippet_backward", "fallback" },
	},

	appearance = {
		-- 'mono' makes nerd-font icons one cell wide so menu columns line up. If
		-- the menu shows tofu boxes, install a Nerd Font or drop the kind_icon
		-- column from completion.menu.draw.columns below.
		nerd_font_variant = "mono",
	},

	-- ── Completion behaviour ─────────────────────────────────────────────────
	completion = {
		list = {
			selection = {
				preselect = false,
				auto_insert = false,
			},
		},

		documentation = {
			-- The delay is the point: without it the doc window flickers open and
			-- shut as you arrow through a list.
			auto_show = true,
			auto_show_delay_ms = 200,
		},

		menu = {
			draw = {
				-- The source column earns its width here: with lsp + snippets + path
				-- + buffer all live and a TSX buffer served by vtsls AND eslint,
				-- where a suggestion came from tells you whether to trust it.
				columns = {
					{ "kind_icon" },
					{ "label", "label_description", gap = 1 },
					{ "source_name" },
				},
			},
		},

		accept = {
			auto_brackets = {
				-- Accepting a function completion adds its parentheses. Pairs with
				-- `completeFunctionCalls` in lsp/vtsls.lua, which supplies the parameter
				-- placeholders — the two together mean accepting `useCallback` gives you
				-- `useCallback(|)` with the cursor inside.
				enabled = true,
			},
		},

		-- Inline preview of the selected item, greyed out ahead of the cursor.
		ghost_text = { enabled = true },
	},

	-- ── Signature help ───────────────────────────────────────────────────────
	-- Always-on parameter hints inside a call, rather than Neovim's on-demand
	-- insert-mode CTRL-S. Worth it for TypeScript generics, where the signature
	-- is the thing you're reading.
	signature = { enabled = true },

	-- ── Sources ──────────────────────────────────────────────────────────────
	sources = {
		-- blink's own default, stated so the list is visible. Order does NOT set
		-- priority (that's score-based below); it only declares which run.
		default = { "lsp", "path", "snippets", "buffer" },

		providers = {
			snippets = { score_offset = 10 },
			lsp = { score_offset = 5 },
			buffer = { score_offset = 3 },
			path = { score_offset = 1 },
		},

		-- friendly-snippets needs no wiring: the snippets provider scans the
		-- runtimepath for it. Installing it in plugins/init.lua is the whole
		-- integration.

		per_filetype = {
			-- Commit messages: buffer words and paths are useful (branch names,
			-- filenames); LSP and snippets are not.
			gitcommit = { "buffer", "path" },
		},
	},

	-- ── Fuzzy matcher ────────────────────────────────────────────────────────
	fuzzy = {
		-- Rust matcher with an auto-downloaded prebuilt binary, falling back to Lua
		-- with a VISIBLE warning. The warning is the point — 'prefer_rust' would
		-- leave you on the slow path silently. Pinning a TAGGED version is what
		-- lets the downloader resolve the matching binary from the git tag.
		implementation = "prefer_rust_with_warning",

		-- Boost items whose text appears near the cursor. Good in React files,
		-- where the prop or variable you want is usually one you just referenced.
		use_proximity = true,
	},

	-- ── Snippets ─────────────────────────────────────────────────────────────
	-- 'default' uses Neovim's built-in vim.snippet (0.10+) rather than LuaSnip.
	-- One less plugin, and LSP-provided snippets work identically either way.
	snippets = { preset = "default" },

	-- ── Cmdline ──────────────────────────────────────────────────────────────
	cmdline = {
		-- Manual trigger only: an auto-showing menu over the cmdline covers the
		-- buffer text you're usually reading in order to type the command.
		-- <C-space> opens it when wanted.
		enabled = true,
		completion = {
			menu = { auto_show = false },
		},
	},
})
