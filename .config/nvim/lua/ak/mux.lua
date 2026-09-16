-- lua/ak/mux.lua
--
-- The multiplexer seam. Neovim asks the terminal multiplexer exactly two
-- things — "move focus to the pane in <direction>" (<C-h/j/k/l>) and "get this
-- message to <agent>" (<leader>ac, via ak/agent.lua) — and tmux and herdr
-- answer both differently. Detection happens once here; a third multiplexer
-- would be one more adapter table, not another detection site.
--
-- ── Interface ──────────────────────────────────────────────────────────────
--
--   M.detect(env)                    -> 'herdr' | 'tmux' | nil  who owns this pane
--   M.reachable(env)                 -> any multiplexer to deliver through?
--   M.deliver(agent, msg, backends)  -> ok, err
--   M.setup()                        -> apply policy, bind the navigation keys
--
-- The trailing parameter defaults to the live process and is the only way to
-- exercise this module without a real multiplexer:
--
--   :lua =require('ak.mux').detect({ TMUX = '/tmp/x' })     -> 'tmux'
--   :lua =require('ak.mux').reachable({ HERDR_ENV = '1' })  -> true
--   :lua =require('ak.mux').deliver('claude', 'hi', {
--          { find = function() return 'p1' end,
--            send = function() return true end } })         -> true
--
-- One exception: the pinned tier of deliver() reads $<AGENT>_PANE from vim.env
-- rather than the backend list, so exercising it means setting
-- vim.env.CLAUDE_PANE first.
--
-- focus() and backends() are deliberately private. Exposing the adapter list
-- invites callers to reimplement the delivery ladder against it — ak/agent.lua
-- used to do exactly that. deliver() keeps the adapter fields to one consumer.
--
-- ── Adapters ───────────────────────────────────────────────────────────────
-- Each multiplexer supplies one table:
--
--   owns_pane(env)                  -> is Neovim directly in one of its panes?
--   reachable(env)                  -> is it around at all, even if we're nested?
--   focus(dir)                      -> the whole motion, split-aware
--   find(agent)                     -> pane target, or nil
--   verify(agent, target)           -> is `agent` really running in target?
--   send(agent, target, msg, quiet) -> ok; notifies unless quiet
--   relay_chord                     -> optional; true when the multiplexer relays
--                                      <M-h/j/k/l> into the pane and setup() must
--                                      bind a landing pad. herdr only.
--
-- owns_pane and reachable are different tests on purpose: Neovim can run in a
-- tmux session nested inside a herdr pane, where tmux owns the pane (so <C-h>
-- speaks tmux) but herdr is still reachable (so an agent in a herdr pane next
-- door is still a valid delivery target).
--
-- `agent` is passed to send because tmux needs it to name its paste buffer.

local M = {}

-- Exposed so ak/agent.lua can test the condition before doing interactive work
-- without restating the wording. deliver() returns this as its `err`.
M.no_backend_error = 'Not inside tmux or herdr'

-- ── Policy ─────────────────────────────────────────────────────────────────
-- Stated once. Under tmux these become vim.g flags vim-tmux-navigator reads;
-- under herdr the adapter implements them by hand, since herdr ships no
-- navigator plugin. Change one and both multiplexers follow.
M.policy = {
  -- Write the buffer when leaving for another pane — you jump to a pane to run
  -- `bin/rspec` against the file you just edited.
  save_on_switch = true,

  -- No wrapping from rightmost pane to leftmost: one <C-l> too many should do
  -- nothing, not teleport you across the screen.
  no_wrap = true,

  -- Don't navigate out of a zoomed pane; zoom means "only this pane". tmux
  -- only — herdr exposes no zoom state, so its adapter can't honour it.
  disable_when_zoomed = true,
}

-- ── Directions ─────────────────────────────────────────────────────────────
-- One row per direction: the `wincmd` letter, the name each multiplexer's CLI
-- uses, and the suffix vim-tmux-navigator puts on its commands. So a direction
-- is spelled once per vocabulary rather than once per keymap.
local directions = {
  { wincmd = 'h', name = 'left', suffix = 'Left' },
  { wincmd = 'j', name = 'down', suffix = 'Down' },
  { wincmd = 'k', name = 'up', suffix = 'Up' },
  { wincmd = 'l', name = 'right', suffix = 'Right' },
}

-- ── Shared motion helpers ──────────────────────────────────────────────────

--- Try the split motion. An unchanged winnr() means `wincmd` had nowhere to go,
--- i.e. we were at the edge of the split layout. Neovim's window motions don't
--- wrap, so `policy.no_wrap` needs nothing extra here.
--- @param wincmd_dir string one of h/j/k/l
--- @return boolean moved
local function move_split(wincmd_dir)
  local before = vim.fn.winnr()
  vim.cmd('wincmd ' .. wincmd_dir)
  return before ~= vim.fn.winnr()
end

--- `update` writes only if the buffer is actually modified; `silent!` swallows
--- the error for buffers that have no file to write to (help, terminals, the
--- picker).
local function save_before_leaving()
  if M.policy.save_on_switch then
    vim.cmd('silent! update')
  end
end

-- ── tmux ───────────────────────────────────────────────────────────────────
-- The Neovim half of christoomey/vim-tmux-navigator; the tmux half is
-- installed via TPM and declared in ~/.dotfiles/.tmux.conf, same repo so the
-- halves stay version-matched.
--
-- The protocol, because it is otherwise mystifying: tmux binds C-h/j/k/l
-- globally and on each press runs a `ps` check on the pane's tty to see if it
-- is running (n)vim. If so it FORWARDS the key rather than switching panes.
-- Neovim tries `wincmd h`, and only if the window number didn't change (i.e.
-- at the split edge) does the plugin shell out to `tmux select-pane -L`. The
-- plugin owns all of it, which is why focus() below is one line and herdr's is
-- hand-rolled.
--
-- If <C-h> ever stops switching, that `ps` detection misfired —
-- `:TmuxNavigatorProcessList` shows tmux what it sees.

-- Recognising an agent's pane BY ITS PROCESS, never by pane title or tmux's
-- pane_current_command. Both used to be matched, and both lie:
--
--   title  oh-my-zsh sets it to the current directory, so a plain shell in
--          ~/code/claude-tools "was" Claude — and got code pasted + Enter
--   cmd    Claude Code has reported its version ("2.1.229") here, so the
--          match was "any process named like a version number"
--
-- What is checked instead: a FOREGROUND process ('+' in ps's STAT) on the
-- pane's tty whose program is the agent. Foreground matters — a shell that
-- backgrounded or merely launched claude earlier isn't where a paste lands.
--
-- The program is the basename of argv[0], or argv[1] when argv[0] is a runtime
-- (npm installs run as `node …/bin/claude`). The version pattern stays as a
-- last resort for builds that retitle their process, but only ever for a
-- foreground process, which a shell prompt never is.
local agent_programs = {
  claude = 'claude',
}

local runtimes = { node = true, bun = true, deno = true }

local function is_agent_process(program, args)
  local argv0, argv1 = args:match('^(%S+)%s*(%S*)')
  if not argv0 then
    return false
  end
  local base0 = vim.fs.basename(argv0)
  if base0 == program or base0:match('^%d+%.%d+%.%d+$') then
    return true
  end
  return runtimes[base0] ~= nil and argv1 ~= '' and vim.fs.basename(argv1) == program
end

-- Every tty with `agent` in the foreground, from ONE ps call — rather than one
-- per pane — as a set keyed the way tmux's #{pane_tty} spells it (/dev/ttys003).
local function tmux_agent_ttys(agent)
  local program = agent_programs[string.lower(agent)]
  if not program then
    return {}
  end
  local r = vim.system({ 'ps', '-axo', 'tty=,stat=,args=' }, { text = true }):wait()
  if r.code ~= 0 then
    return {}
  end
  local ttys = {}
  for line in vim.gsplit(r.stdout or '', '\n', { trimempty = true }) do
    local tty, stat, args = line:match('^%s*(%S+)%s+(%S+)%s+(.*)$')
    if tty and tty ~= '??' and stat:find('+', 1, true) and is_agent_process(program, args) then
      ttys['/dev/' .. tty] = true
    end
  end
  return ttys
end

-- Find the pane running `agent`, preferring current window > rest of session >
-- other sessions, so two agents side by side resolve to the near one.
local function tmux_find(agent)
  local ttys = tmux_agent_ttys(agent)
  local fmt = '#{pane_id}\t#{window_active}\t#{session_attached}\t#{pane_tty}'
  local r = vim.system({ 'tmux', 'list-panes', '-a', '-F', fmt }, { text = true }):wait()
  if r.code ~= 0 then
    return nil
  end

  local best, best_rank
  for line in vim.gsplit(r.stdout or '', '\n', { trimempty = true }) do
    local id, win_active, sess_attached, tty = line:match('^(%S+)\t(%d)\t(%d)\t(.*)$')
    -- never target ourselves: $TMUX_PANE is this nvim's own pane
    if id and id ~= vim.env.TMUX_PANE and ttys[tty] then
      local rank = (win_active == '1' and 0 or 1) + (sess_attached == '1' and 0 or 2)
      if not best_rank or rank < best_rank then
        best, best_rank = id, rank
      end
    end
  end
  return best
end

-- A pinned $CLAUDE_PANE gets the same process check as discovery. tmux pane
-- ids are reused after a server restart, so a stale export in a shell profile
-- can name a pane that is now a shell.
local function tmux_verify(agent, target)
  local r = vim.system(
    { 'tmux', 'display-message', '-p', '-t', target, '#{pane_id}\t#{pane_tty}' },
    { text = true }
  ):wait()
  if r.code ~= 0 then
    return false
  end
  local id, tty = (r.stdout or ''):match('^(%S+)\t(%S+)')
  return id ~= nil and id ~= vim.env.TMUX_PANE and tmux_agent_ttys(agent)[tty] == true
end

-- Via a named buffer rather than `send-keys`, so the text arrives as a bracketed
-- paste (-p) and the agent's prompt reads newlines as newlines instead of
-- submitting on the first one. `-d` deletes the buffer after; a separate
-- send-keys Enter submits.
local function tmux_send(agent, target, msg, quiet)
  local function tmux(args, stdin)
    local r = vim.system(vim.list_extend({ 'tmux' }, args), { stdin = stdin }):wait()
    if r.code ~= 0 and not quiet then
      vim.notify('tmux: ' .. (r.stderr or ''), vim.log.levels.ERROR)
    end
    return r.code == 0
  end

  local buffer = 'nvim_' .. string.lower(agent)

  if not tmux({ 'load-buffer', '-b', buffer, '-' }, msg) then
    return false
  end
  if not tmux({ 'paste-buffer', '-b', buffer, '-t', target, '-d', '-p' }) then
    return false
  end
  return tmux({ 'send-keys', '-t', target, 'Enter' })
end

-- For tmux the two questions collapse: $TMUX is set only inside a tmux pane, so
-- owns_pane and reachable have the same answer. herdr is where they differ.
local function tmux_present(env)
  return env.TMUX ~= nil and env.TMUX ~= ''
end

local tmux_adapter = {
  name = 'tmux',

  owns_pane = tmux_present,
  reachable = tmux_present,

  -- The plugin owns the whole motion, split-edge test and policy flags
  -- included. The command only exists once its plugin/ file has sourced, which
  -- vim.pack defers until after init.lua — but that's before any keypress.
  focus = function(dir)
    vim.cmd('TmuxNavigate' .. dir.suffix)
  end,

  find = tmux_find,
  verify = tmux_verify,
  send = tmux_send,
}

-- ── herdr ──────────────────────────────────────────────────────────────────
-- herdr ships no navigator plugin, so this adapter inverts the tmux protocol.
-- A herdr keybinding is unconditional — bind ctrl+h to focus_pane_left and
-- herdr swallows the key, leaving Neovim splits unreachable. So the (n)vim
-- check tmux does in its own plugin is hand-rolled in .config/herdr/herdr-nav.sh,
-- which config.toml binds all four keys to:
--
--   not running Neovim -> the script focuses the neighbouring herdr pane
--   running Neovim     -> the script relays alt+h/j/k/l in, and focus() below
--                         tries `wincmd h` first, shelling out to
--                         `herdr pane focus` only at the split edge
--
-- The relay uses the ALT chord, never the ctrl one herdr is bound to, so a
-- relayed key can't retrigger herdr's own binding. `--current` resolves via
-- $HERDR_PANE_ID, which herdr exports into every pane and Neovim inherits.

-- No title/process sniffing: herdr classifies agents itself and reports a
-- canonical kind per pane, so `agent list` IS the table tmux_agent_ttys has to
-- reconstruct for tmux.
--
-- Returns only well-formed entries for `agent`, excluding this nvim's own pane.
local function herdr_agents(agent)
  local r = vim.system({ 'herdr', 'agent', 'list' }):wait()
  if r.code ~= 0 then
    return {}
  end
  -- type-check every hop rather than rely on truthiness: vim.json.decode maps
  -- JSON null to vim.NIL, a userdata that is truthy and blows up on index.
  local ok, decoded = pcall(vim.json.decode, r.stdout or '')
  if not ok or type(decoded) ~= 'table' or type(decoded.result) ~= 'table' then
    return {}
  end
  local agents = decoded.result.agents
  if type(agents) ~= 'table' then
    return {}
  end

  local want = string.lower(agent)
  local found = {}
  for _, a in ipairs(agents) do
    -- never target ourselves: $HERDR_PANE_ID is this nvim's own pane
    if
      type(a) == 'table'
      and a.agent == want
      and type(a.pane_id) == 'string'
      and a.pane_id ~= vim.env.HERDR_PANE_ID
    then
      found[#found + 1] = a
    end
  end
  return found
end

-- Ranking mirrors tmux's — same tab beats same workspace — so two agents side
-- by side resolve to the near one.
local function herdr_find(agent)
  local best, best_rank
  for _, a in ipairs(herdr_agents(agent)) do
    local rank = (a.tab_id == vim.env.HERDR_TAB_ID and 0 or 1)
      + (a.workspace_id == vim.env.HERDR_WORKSPACE_ID and 0 or 2)
    if not best_rank or rank < best_rank then
      best, best_rank = a.pane_id, rank
    end
  end
  return best
end

-- `agent prompt` would accept any agent kind, so a pin naming a codex pane
-- would otherwise get Claude's message.
local function herdr_verify(agent, target)
  for _, a in ipairs(herdr_agents(agent)) do
    if a.pane_id == target then
      return true
    end
  end
  return false
end

-- `agent prompt` submits text and Enter in one call, honouring the pane's live
-- bracketed-paste mode, so none of the tmux buffer dance is needed. No --wait:
-- hand the prompt over and get out of the way.
local function herdr_send(_agent, target, msg, quiet)
  local r = vim.system({ 'herdr', 'agent', 'prompt', target, msg }):wait()
  if r.code ~= 0 and not quiet then
    vim.notify('herdr: ' .. (r.stderr or ''), vim.log.levels.ERROR)
  end
  return r.code == 0
end

local herdr_adapter = {
  name = 'herdr',

  owns_pane = function(env)
    return env.HERDR_PANE_ID ~= nil and env.HERDR_PANE_ID ~= ''
  end,

  -- $HERDR_ENV rather than $HERDR_PANE_ID: a nested tmux session inside a herdr
  -- pane still has a herdr server to talk to, even though tmux owns the pane.
  reachable = function(env)
    return env.HERDR_ENV == '1'
  end,

  -- Fire and forget: vim.fn.system() would block the UI on every edge press for
  -- the round trip to herdr's socket. Nothing reads the result — if focus fails
  -- there's nothing useful to do, and it has already visibly not moved.
  focus = function(dir)
    if move_split(dir.wincmd) then
      return
    end
    save_before_leaving()
    vim.system({ 'herdr', 'pane', 'focus', '--direction', dir.name, '--current' })
  end,

  find = herdr_find,
  verify = herdr_verify,
  send = herdr_send,

  -- herdr-nav.sh relays <M-h/j/k/l> into the pane, so those chords need a
  -- landing pad. See M.setup().
  relay_chord = true,
}

-- ── No multiplexer ─────────────────────────────────────────────────────────
-- Bare terminal: split motions still apply the save-on-switch policy, and
-- there's nothing beyond the edge to move to.
local none_adapter = {
  name = 'window',
  owns_pane = function()
    return true
  end,
  reachable = function()
    return false
  end,
  focus = function(dir)
    move_split(dir.wincmd)
  end,
  find = function()
    return nil
  end,
  verify = function()
    return false
  end,
  send = function()
    return false
  end,
}

-- ── Detection ──────────────────────────────────────────────────────────────

-- Ordered: herdr first, for both detection and agent delivery.
local adapters = { herdr_adapter, tmux_adapter }

--- Which multiplexer owns the pane this Neovim is running in.
--- Pure: pass any table to ask about that environment instead of this process.
---
--- herdr wins when both are present. In that nesting (tmux inside a herdr pane)
--- navigation is herdr's regardless: it is the OUTER multiplexer so it consumes
--- ctrl+h first, and herdr-nav.sh sees `tmux` as the foreground process rather
--- than nvim, so the keystroke never reaches Neovim. Agent delivery still works
--- there — that is what backends_for() is for.
--- @param env table
--- @return table adapter never nil — falls back to none_adapter
local function adapter_for(env)
  for _, adapter in ipairs(adapters) do
    if adapter.owns_pane(env) then
      return adapter
    end
  end
  return none_adapter
end

--- Adapters worth trying for agent delivery, nearest first.
---
--- A LIST rather than one pick: "inside herdr" doesn't prove the agents are
--- herdr's — nvim can sit in a nested tmux session with the agents in tmux
--- panes. herdr is asked first and we fall through when it has nothing.
--- Private; see the note on backends() at the top of this file.
--- @param env table
--- @return table[]
local function backends_for(env)
  local list = {}
  for _, adapter in ipairs(adapters) do
    if adapter.reachable(env) then
      list[#list + 1] = adapter
    end
  end
  return list
end

--- @param env table|nil defaults to vim.env
--- @return string|nil 'herdr', 'tmux', or nil for a bare terminal
function M.detect(env)
  local adapter = adapter_for(env or vim.env)
  return adapter ~= none_adapter and adapter.name or nil
end

--- Is there any multiplexer we could deliver a message through?
---
--- Lets a caller bail BEFORE expensive or interactive work — ak/agent.lua checks
--- this before prompting for a question rather than after.
---
--- NOT the same question as detect(), which asks who owns this pane:
---
---   TMUX + HERDR_ENV + HERDR_PANE_ID  detect 'herdr'  reachable true
---   TMUX + HERDR_ENV                  detect 'tmux'   reachable true
---   HERDR_ENV                         detect nil      reachable TRUE   <- diverges
---   (nothing)                         detect nil      reachable false
--- @param env table|nil defaults to vim.env
--- @return boolean
function M.reachable(env)
  return #backends_for(env or vim.env) > 0
end

-- ── Delivery ───────────────────────────────────────────────────────────────
-- The ladder that gets a message to an agent, and the only consumer of an
-- adapter's find/verify/send fields.
--
-- NO GUESS TIER, on purpose. There used to be one: with no agent found, tmux
-- pasted into "the next pane" and pressed Enter. When that pane was a shell —
-- or an ssh session — the selected code ran as commands. Every target is now
-- either discovered by process or a pin that passed the same check.
--
-- $<AGENT>_PANE (e.g. CLAUDE_PANE) pins a destination: a tmux
-- target-pane ("%3", "session:win.0") or a herdr pane id ("wF:p6"). The formats
-- aren't interchangeable, so a rejected pin is not fatal — we move on rather
-- than fail on a stale export in a shell profile.

--- Get `msg` to `agent`, wherever it is running.
---
--- Two tiers, tried in order: a pinned pane, then discovery. Both require the
--- target to be verifiably running `agent`; otherwise nothing is sent.
---
--- @param agent string 'Claude' — matched case-insensitively
--- @param msg string
--- @param backends table[]|nil adapters to try, nearest first; defaults to those
---        reachable from this process. Pass fakes to exercise the ladder.
--- @return boolean ok
--- @return string|nil err nil when the adapter already reported it with the
---         actual stderr, which beats anything we could say here
function M.deliver(agent, msg, backends)
  backends = backends or backends_for(vim.env)
  if #backends == 0 then
    return false, M.no_backend_error
  end

  local env_name = string.upper(agent) .. '_PANE'
  local pinned = vim.env[env_name]

  -- EVERY backend gets a try, not just the nearest: in nested setups both are
  -- reachable and a $CLAUDE_PANE holding a tmux id only means anything to the
  -- tmux adapter, which is never backends[1] since herdr sorts first.
  if pinned then
    for _, backend in ipairs(backends) do
      if backend.verify(agent, pinned) then
        return backend.send(agent, pinned, msg)
      end
    end
    vim.notify(
      ('$%s (%s) is not a %s pane; looking for one instead.'):format(env_name, pinned, agent),
      vim.log.levels.WARN
    )
  end

  for _, backend in ipairs(backends) do
    local target = backend.find(agent)
    if target then
      return backend.send(agent, target, msg)
    end
  end

  return false, ('No %s agent pane found. Set $%s to pin one.'):format(agent, env_name)
end

-- ── Setup ──────────────────────────────────────────────────────────────────

--- Apply the policy and bind the navigation keys. Call from init.lua; load
--- order doesn't matter, since this is the only place that binds <C-h/j/k/l>.
function M.setup()
  -- Set unconditionally, including under herdr and in a bare terminal.
  --
  -- `no_mappings` is the load-bearing one: without it vim-tmux-navigator's
  -- plugin/ file installs its own <C-h/j/k/l> maps when it sources — which
  -- happens AFTER init.lua finishes, clobbering whatever we bind below no
  -- matter what order this runs in.
  --
  -- The rest are read at source time and only mean anything under tmux, but
  -- setting them always keeps the policy in one branch-free block.
  vim.g.tmux_navigator_no_mappings = 1
  vim.g.tmux_navigator_save_on_switch = M.policy.save_on_switch and 1 or 0
  vim.g.tmux_navigator_no_wrap = M.policy.no_wrap and 1 or 0
  vim.g.tmux_navigator_disable_when_zoomed = M.policy.disable_when_zoomed and 1 or 0

  local backend = adapter_for(vim.env)
  local map = vim.keymap.set

  -- Normal mode only, which is what keeps these clear of:
  --   blink.cmp's <C-h>/<C-l> snippet jumps      (insert mode)
  --   keymaps.lua's <A-h/j/k/l> cursor movement  (insert mode)
  --   the snacks picker's <C-h> edit_split       (buffer-local, and correctly
  --                                               shadows navigation while open)
  for _, dir in ipairs(directions) do
    local handler = function()
      backend.focus(dir)
    end
    local desc = 'Navigate ' .. dir.name .. ' (split or ' .. backend.name .. ' pane)'

    map('n', '<C-' .. dir.wincmd .. '>', handler, { desc = desc })

    -- Under herdr this is the chord that actually fires: herdr-nav.sh relays it
    -- in via send-keys, straight into the pane's PTY, so it works regardless of
    -- how the outer terminal treats Option. With `macos-option-as-alt = left`
    -- in ghostty/config, left Option+h reaches Neovim as <M-h> too — same
    -- handler either way.
    if backend.relay_chord then
      map('n', '<M-' .. dir.wincmd .. '>', handler, { desc = desc })
    end
  end
end

return M
