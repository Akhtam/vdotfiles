-- lua/ak/herdr.lua
--
-- Seamless <C-h/j/k/l> movement between Neovim splits and herdr panes.
--
-- This is the herdr counterpart to lua/ak/plugins/tmux.lua: same user-facing
-- behaviour, different machinery, because herdr ships no navigator plugin.
--
-- vim-tmux-navigator works because tmux binds C-h/j/k/l globally and, on each
-- press, runs a `ps` check on the pane's tty to decide whether to forward the
-- key or switch panes itself. That conditional lives on the tmux side, in a
-- plugin. herdr has no such plugin, and a herdr keybinding is unconditional:
-- if config.toml binds ctrl+h to focus_pane_left, herdr swallows it and Neovim
-- never sees it, so Neovim splits become unreachable.
--
-- So the conditional is hand-rolled in a shell script instead. herdr DOES bind
-- all four keys — to ~/.dotfiles/.config/herdr/herdr-nav.sh, which runs the
-- (n)vim check herdr itself won't:
--
--   pane isn't running Neovim -> the script focuses the neighbouring herdr
--   pane and this file is never involved.
--
--   pane IS running Neovim -> the script relays alt+h/j/k/l into the pane and
--   the maps below take over: try `wincmd h` first, and only when the window
--   number didn't change — i.e. we were already at the edge of the split
--   layout — shell back out to `herdr pane focus --direction left --current`.
--
-- The relay deliberately uses the alt chord, never the ctrl one herdr is bound
-- to, so a relayed key can never retrigger herdr's own binding. The reasoning
-- is in the comment block in ~/.dotfiles/.config/herdr/config.toml.
--
-- `--current` resolves via $HERDR_PANE_ID, which herdr exports into every pane
-- and Neovim inherits, so no pane id bookkeeping is needed here.

-- ── Guard ──────────────────────────────────────────────────────────────────
-- Outside herdr this module must do nothing at all, so that the tmux mappings
-- in plugins/tmux.lua stay in force when Neovim is running under tmux (or bare)
-- instead. init.lua requires this file AFTER ak.plugins for exactly that
-- reason: inside herdr these maps land last and win.
if vim.env.HERDR_PANE_ID == nil or vim.env.HERDR_PANE_ID == '' then
  return
end

-- ── Navigation ─────────────────────────────────────────────────────────────

--- Move to the split in `wincmd_dir`; if already at the edge, move to the herdr
--- pane in `herdr_dir` instead.
--- @param wincmd_dir string one of h/j/k/l
--- @param herdr_dir string one of left/down/up/right
--- @return function
local function nav(wincmd_dir, herdr_dir)
  return function()
    local before = vim.fn.winnr()
    vim.cmd('wincmd ' .. wincmd_dir)

    -- winnr() unchanged means `wincmd` had nowhere to go. Neovim's window
    -- motions don't wrap, which is what we want — it matches the
    -- `vim.g.tmux_navigator_no_wrap = 1` set in plugins/tmux.lua. That policy
    -- is now stated in two places; if you change your mind about wrapping,
    -- grep for tmux_navigator_no_wrap and you will find both.
    if before ~= vim.fn.winnr() then
      return
    end

    -- The hand-rolled equivalent of `vim.g.tmux_navigator_save_on_switch = 1`
    -- (same caveat as above — two statements of one policy): you jump to a
    -- neighbouring pane to run the tests against the file you just edited, and
    -- without this you'd be testing the previous version of it. `update` writes
    -- only if the buffer is actually modified; `silent!` swallows the error for
    -- buffers that have no file to write to (help, terminals, the picker).
    vim.cmd('silent! update')

    -- Fire and forget. vim.fn.system() would block the UI on every edge press
    -- for the round trip to herdr's socket; vim.system() without :wait() does
    -- not. We never read the result — if the pane focus fails there is nothing
    -- useful to do about it, and focus has already visibly not moved.
    vim.system({ 'herdr', 'pane', 'focus', '--direction', herdr_dir, '--current' })
  end
end

-- ── Keymaps ────────────────────────────────────────────────────────────────
-- Normal mode only, matching plugins/tmux.lua. The conflicts checked there
-- hold here too: blink.cmp's <C-h>/<C-l> are insert mode, and the snacks
-- picker's <C-h> is buffer-local and correctly shadows these while open.
--
-- Both chords get bound, for two different reasons:
--
--   <M-h/j/k/l> is what actually fires in normal use — it is the chord
--   herdr-nav.sh relays in. You cannot type it yourself: per the note in
--   keymaps.lua, Ghostty runs with macos-option-as-alt unset, so Option+h types
--   `˙` and Neovim never sees <M-h>. That doesn't matter here, because herdr's
--   send-keys writes the chord straight into the pane's PTY, which never passes
--   through Ghostty's Option handling. These are the relay's landing pad.
--
--   <C-h/j/k/l> is bound to displace plugins/tmux.lua, which mapped those same
--   four keys to <cmd>TmuxNavigate*<CR> unconditionally. Inside herdr there is
--   no tmux for those to talk to, so they are wrong here regardless of whether
--   herdr's own ctrl bindings have loaded. In a fully configured herdr they
--   never fire (herdr consumes ctrl+h/j/k/l first); in a server that hasn't
--   picked up config.toml yet, they are what makes navigation work at all.
local map = vim.keymap.set

-- `wincmd` letter paired with the herdr --direction name it corresponds to.
-- One table rather than one hand-written map call per key, so a direction is
-- spelled once per vocabulary instead of once per keymap.
local directions = {
  { 'h', 'left' },
  { 'j', 'down' },
  { 'k', 'up' },
  { 'l', 'right' },
}

for _, direction in ipairs(directions) do
  local wincmd_dir, herdr_dir = direction[1], direction[2]
  local handler = nav(wincmd_dir, herdr_dir)
  local desc = 'Navigate ' .. herdr_dir .. ' (split or herdr pane)'

  map('n', '<M-' .. wincmd_dir .. '>', handler, { desc = desc })
  map('n', '<C-' .. wincmd_dir .. '>', handler, { desc = desc })
end
