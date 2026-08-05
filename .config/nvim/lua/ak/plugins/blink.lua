-- lua/ak/plugins/blink.lua
--
-- Completion. Pinned to the 1.x line in plugins/init.lua — v2 is mid-rewrite
-- and needs a separate blink.lib plugin.
--
-- Every option below was checked against the installed v1.10.2 schema in
-- lua/blink/cmp/config/, not copied from a blog post. blink's own defaults are
-- good, so this file is mostly small deviations plus the reasoning for them.

require("blink.cmp").setup({
	-- ── Keymap ───────────────────────────────────────────────────────────────
	-- Presets available in v1.10.2: 'none', 'default', 'enter', 'super-tab'.
	--
	-- 'default' keeps completion on Ctrl keys and leaves Tab and Enter alone:
	--   <C-space>  open menu / open docs
	--   <C-n>/<C-p> or <Up>/<Down>  cycle items
	--   <C-y>      accept
	--   <C-e>      dismiss
	--   <C-k>      toggle signature help
	--
	-- Chosen over 'super-tab' and 'enter' deliberately. Both of those overload a
	-- key that already means something: Enter must still insert a newline, and
	-- Tab must still indent. Overloading them means the menu's visibility silently
	-- changes what a keystroke does, which produces exactly the class of bug where
	-- you press Enter for a newline and get a completion you didn't want.
	-- <C-y> is unambiguous — it only ever means accept.
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
		-- 'mono' makes nerd-font icons occupy one cell so the menu columns line up.
		-- JetBrains Mono NL has no icon glyphs of its own — these come from a Nerd
		-- Font fallback. If the menu shows tofu boxes, either install a Nerd Font
		-- or set completion.menu.draw.columns below to drop the kind_icon column.
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
			-- Show the doc window automatically, after a beat. The delay is the whole
			-- point: without it the window flickers open and shut as you arrow through
			-- a list. 200ms is long enough to imply intent, short enough not to wait.
			auto_show = true,
			auto_show_delay_ms = 200,
		},

		menu = {
			draw = {
				-- Kind icon, label, then the source. The source column matters in this
				-- config specifically: with lsp + snippets + path + buffer all live, and
				-- a TSX buffer served by both vtsls and eslint, knowing where a
				-- suggestion came from tells you whether to trust it.
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
	-- Parameter hints while typing inside a call. Neovim binds CTRL-S in insert
	-- mode to vim.lsp.buf.signature_help() by default; this is the always-on
	-- version, which is more useful for TypeScript generics where the signature
	-- is the thing you're actually reading.
	signature = { enabled = true },

	-- ── Sources ──────────────────────────────────────────────────────────────
	sources = {
		-- Matches blink's own default; stated explicitly so the list is visible.
		-- Order does NOT determine priority — that's score-based — it just declares
		-- which providers run.
		default = { "lsp", "path", "snippets", "buffer" },

		providers = {
			snippets = { score_offset = 10 },
			lsp = { score_offset = 5 },
			buffer = { score_offset = 3 },
			path = { score_offset = 1 },
		},

		-- friendly-snippets needs no wiring: the default snippets provider sets
		-- `friendly_snippets = true` and scans the runtimepath for any plugin
		-- matching 'friendly.snippets'. Installing it in plugins/init.lua is the
		-- entire integration.

		per_filetype = {
			-- Commit messages: buffer words and paths are useful (branch names,
			-- filenames); LSP and snippets are not.
			gitcommit = { "buffer", "path" },
		},
	},

	-- ── Fuzzy matcher ────────────────────────────────────────────────────────
	fuzzy = {
		-- 'prefer_rust_with_warning' is blink's own recommended value: use the Rust
		-- matcher, download a prebuilt binary automatically, and fall back to Lua
		-- with a visible warning if that fails.
		--
		-- The warning is the point. The silent variant ('prefer_rust') would leave
		-- you on the slow path without ever saying so. Because we pinned a TAGGED
		-- version, the downloader can resolve the matching binary from the git tag —
		-- this is a concrete benefit of pinning that isn't obvious up front.
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
		-- Completion in : and / . Kept to a manual trigger: an auto-showing menu
		-- over the cmdline covers the buffer text you are often reading in order to
		-- type the command. <C-space> opens it when wanted.
		enabled = true,
		completion = {
			menu = { auto_show = false },
		},
	},
})
