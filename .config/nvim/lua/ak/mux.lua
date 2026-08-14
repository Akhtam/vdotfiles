-- lua/ak/mux.lua
--
-- The multiplexer seam, in one module.
--
-- Exactly two things get asked of the terminal multiplexer from inside Neovim:
--
--   "move focus to the pane in <direction>"   — the <C-h/j/k/l> maps
--   "get this message to <agent>"             — <leader>ac / <leader>ao, ak/agent.lua
--
-- Both are answered differently under tmux and under herdr, and each answer
-- used to carry its own copy of "which multiplexer am I in": plugins/tmux.lua
-- assumed tmux, ak/herdr.lua tested $HERDR_PANE_ID, ak/agent.lua tested
-- $HERDR_ENV and $TMUX, and .config/herdr/herdr-nav.sh asked the herdr server.
-- Four tests of one fact, plus two independent statements of the same
-- no-wrap / save-on-switch policy.
--
-- Now the fact is established once, the policy is stated once, and a third
-- multiplexer would be one adapter table rather than a fifth detection site.
--
-- ── Interface ──────────────────────────────────────────────────────────────
--
--   M.detect(env)                    -> 'herdr' | 'tmux' | nil  which multiplexer owns this pane
--   M.reachable(env)                 -> is there any multiplexer to deliver through?
--   M.deliver(agent, msg, backends)  -> ok, err   get msg to agent, wherever it is
--   M.setup()                        -> apply policy, bind the navigation keys
--
-- The three queries take an optional trailing table — an env for the first two,
-- a backend list for deliver — defaulting to the live process. (setup() takes
-- none; it acts on this process by definition.) That parameter is not
-- decoration: it is the only way to exercise this module without a live
-- multiplexer, and the way each was checked when it was written —
--
--   :lua =require('ak.mux').detect({ TMUX = '/tmp/x' })     -> 'tmux'
--   :lua =require('ak.mux').reachable({ HERDR_ENV = '1' })  -> true
--
-- deliver() needs adapters rather than an env, so its fakes are a little more
-- than a table literal — each needs find/send/fallback:
--
--   :lua =require('ak.mux').deliver('claude', 'hi', {
--          { find = function() return 'p1' end,
--            send = function() print('sent') return true end } })   -> true
--
-- One tier still reads the live process: $<AGENT>_PANE is looked up via
-- vim.env, not the backend list, so exercising the pinned tier means setting
-- vim.env.CLAUDE_PANE first. Everything else is driven by the argument.
--
-- What is deliberately NOT in this interface, and why:
--
--   focus(dir)   the four keymaps in setup() are its only caller and they hold
--                the adapter already, so a public focus() would exist purely to
--                be re-looked-up on every keypress.
--
--   backends()   handing out the adapter list makes the adapter TABLE public,
--                and a caller that holds adapters inevitably reimplements the
--                delivery ladder against them — which is exactly what
--                ak/agent.lua used to do: it indexed backends[1], read
--                .fallback, and called .find/.send itself. deliver() exists so
--                that the adapter fields have exactly one consumer, in this
--                file.
--
-- ── Adapters ───────────────────────────────────────────────────────────────
-- Each multiplexer supplies one table:
--
--   owns_pane(env)                  -> is Neovim sitting directly in one of its panes?
--   reachable(env)                  -> is it around at all, even if we're nested?
--   focus(dir)                      -> the whole motion, split-aware
--   find(agent)                     -> pane target, or nil
--   send(agent, target, msg, quiet) -> ok; notifies unless quiet
--   fallback                        -> target to guess at, or nil for "don't"
--   relay_chord                     -> optional. true when the multiplexer
--                                      relays <M-h/j/k/l> into the pane and
--                                      setup() must bind a landing pad for it.
--                                      herdr only; see its adapter.
--
-- owns_pane and reachable are deliberately different tests, not an oversight:
-- Neovim can run in a tmux session nested inside a herdr pane. tmux owns the
-- pane (so <C-h> must speak tmux), while herdr is still reachable (so an agent
-- running in a herdr pane next door is still a valid delivery target).
--
-- `agent` is passed to send because tmux needs it to name its paste buffer.

local M = {}

-- The one condition a caller may want to test for itself before doing
-- expensive or interactive work, so the wording lives in one place rather than
-- once here and once in ak/agent.lua. deliver() returns this as its `err`.
M.no_backend_error = 'Not inside tmux or herdr'

-- ── Policy ─────────────────────────────────────────────────────────────────
-- Stated once, here. Under tmux these become vim.g flags that
-- vim-tmux-navigator reads; under herdr the adapter below implements them by
-- hand, because herdr ships no navigator plugin. Change one of these and both
-- multiplexers follow.
M.policy = {
  -- Write the current buffer when leaving Neovim for another pane. You jump to
  -- a pane to run `bin/rspec` or `pnpm test` against the file you just edited,
  -- and without this you'd be running the previous version of it.
  save_on_switch = true,

  -- Don't wrap around from the rightmost pane to the leftmost. Wrapping means
  -- a <C-l> too many teleports you across the screen instead of doing nothing.
  no_wrap = true,

  -- When a tmux pane is zoomed, don't navigate out of it — zoom means "I want
  -- only this pane", and silently leaving it is disorienting. tmux only: herdr
  -- exposes no zoom state to test, so its adapter cannot honour this.
  disable_when_zoomed = true,
}

-- ── Directions ─────────────────────────────────────────────────────────────
-- The `wincmd` letter paired with the direction name each multiplexer's CLI
-- uses, and the suffix vim-tmux-navigator puts on its commands. One row per
-- direction, so a direction is spelled once per vocabulary rather than once
-- per keymap.
local directions = {
  { wincmd = 'h', name = 'left', suffix = 'Left' },
  { wincmd = 'j', name = 'down', suffix = 'Down' },
  { wincmd = 'k', name = 'up', suffix = 'Up' },
  { wincmd = 'l', name = 'right', suffix = 'Right' },
}

-- ── Shared motion helpers ──────────────────────────────────────────────────

--- Try the split motion. Returns true when the cursor actually moved.
--- winnr() unchanged means `wincmd` had nowhere to go — we were already at the
--- edge of the split layout. Neovim's window motions don't wrap, which is what
--- `policy.no_wrap` asks for, so nothing extra is needed to honour it here.
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
-- The NVIM half of a paired plugin: christoomey/vim-tmux-navigator, whose tmux
-- half is installed via TPM at ~/.tmux/plugins/vim-tmux-navigator and declared
-- in ~/.dotfiles/.tmux.conf. Both halves ship from the same repo, so they stay
-- version-matched.
--
-- How it works, in one paragraph, because the behaviour is otherwise
-- mystifying: tmux binds C-h/j/k/l globally and, on each press, runs a `ps`
-- check on the pane's tty to decide whether the pane is running (n)vim. If it
-- is, tmux FORWARDS the keystroke instead of switching panes. Neovim then tries
-- `wincmd h`; if the window number didn't change it was already at the edge, so
-- the plugin shells out to `tmux select-pane -L`. That is the entire protocol,
-- and the plugin owns all of it — which is why this adapter's focus() is one
-- line while herdr's is a hand-rolled equivalent.
--
-- Practical consequence: if <C-h> ever stops switching, the `ps`-based
-- detection misfired. `:TmuxNavigatorProcessList` shows tmux exactly what it
-- sees, which is the fastest way to diagnose it.

-- How to recognise each agent from `tmux list-panes` output. Both agents set a
-- pane title, but only OpenCode keeps a recognisable process name:
--
--   opencode  cmd=opencode   title=OpenCode
--   claude    cmd=2.1.229    title=◐ Fix Claude default selection in split view
--
-- Claude Code renames its process to its own version number, so the version
-- pattern IS the signature. The title is checked first for both, since it is
-- the one field the agent sets deliberately.
local agent_matchers = {
  claude = function(cmd, title)
    return title:find('claude', 1, true) or cmd:find('claude', 1, true) or cmd:match('^%d+%.%d+%.%d+$') ~= nil
  end,
  opencode = function(cmd, title)
    return title:find('opencode', 1, true) or cmd:find('opencode', 1, true)
  end,
}

-- Find the pane running `agent`, preferring the current window over the rest of
-- the session over other sessions — so with two agents side by side in this
-- window you always hit the one you asked for. Returns nil when nothing matches.
local function tmux_find(agent)
  local matches = agent_matchers[string.lower(agent)]
  local fmt = '#{pane_id}\t#{window_active}\t#{session_attached}\t#{pane_current_command}\t#{pane_title}'
  local r = vim.system({ 'tmux', 'list-panes', '-a', '-F', fmt }):wait()
  if r.code ~= 0 or not matches then
    return nil
  end

  local best, best_rank
  for line in vim.gsplit(r.stdout or '', '\n', { trimempty = true }) do
    local id, win_active, sess_attached, cmd, title = line:match('^(%S+)\t(%d)\t(%d)\t([^\t]*)\t(.*)$')
    -- never target ourselves: $TMUX_PANE is this nvim's own pane
    if id and id ~= vim.env.TMUX_PANE and matches(string.lower(cmd), string.lower(title)) then
      local rank = (win_active == '1' and 0 or 1) + (sess_attached == '1' and 0 or 2)
      if not best_rank or rank < best_rank then
        best, best_rank = id, rank
      end
    end
  end
  return best
end

-- Delivery goes through a named tmux buffer rather than `send-keys` so the text
-- arrives as a bracketed paste (-p): the agent's prompt sees the newlines as
-- literal newlines instead of submitting on the first one. `-d` deletes the
-- buffer after pasting. A separate `send-keys Enter` submits.
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

-- For tmux the two questions collapse into one: $TMUX is set only inside a tmux
-- pane, so "does tmux own this pane" and "is tmux reachable" have the same
-- answer. herdr is the case where they genuinely differ — see its adapter.
local function tmux_present(env)
  return env.TMUX ~= nil and env.TMUX ~= ''
end

local tmux_adapter = {
  name = 'tmux',

  owns_pane = tmux_present,
  reachable = tmux_present,

  -- The plugin owns the whole motion, including the split-edge test and both
  -- policy flags, so there is nothing to hand-roll. The command only exists
  -- once the plugin's plugin/ file has sourced, which vim.pack defers until
  -- after init.lua finishes — by the time a key is actually pressed, it is
  -- there.
  focus = function(dir)
    vim.cmd('TmuxNavigate' .. dir.suffix)
  end,

  find = tmux_find,
  send = tmux_send,

  -- tmux can still guess "the pane next door" when discovery finds nothing.
  fallback = '.+',
}

-- ── herdr ──────────────────────────────────────────────────────────────────
-- herdr ships no navigator plugin, so this adapter inverts the tmux protocol.
--
-- A herdr keybinding is unconditional: if config.toml binds ctrl+h to
-- focus_pane_left, herdr swallows the key and Neovim never sees it, so Neovim
-- splits would become unreachable. The (n)vim check that tmux does in its own
-- plugin is therefore hand-rolled on the herdr side, in
-- .config/herdr/herdr-nav.sh, which config.toml binds all four keys to:
--
--   pane isn't running Neovim -> the script focuses the neighbouring herdr
--   pane, and Neovim is never involved.
--
--   pane IS running Neovim -> the script relays alt+h/j/k/l into the pane and
--   focus() below takes over: try `wincmd h` first, and only at the edge of the
--   split layout shell back out to `herdr pane focus`.
--
-- The relay deliberately uses the alt chord, never the ctrl one herdr is bound
-- to, so a relayed key can never retrigger herdr's own binding. The reasoning
-- is in the comment block in .config/herdr/config.toml.
--
-- `--current` resolves via $HERDR_PANE_ID, which herdr exports into every pane
-- and Neovim inherits, so no pane id bookkeeping is needed here.

-- No title/process sniffing: herdr classifies agents itself and reports a
-- canonical kind ("claude", "opencode") per pane, so `agent list` IS the lookup
-- table that agent_matchers has to reconstruct for tmux.
--
-- Ranking mirrors the tmux one — same tab beats same workspace beats anything
-- else — so two agents side by side resolve to the near one.
local function herdr_find(agent)
  local r = vim.system({ 'herdr', 'agent', 'list' }):wait()
  if r.code ~= 0 then
    return nil
  end
  -- type-check every hop rather than rely on truthiness: vim.json.decode maps
  -- JSON null to vim.NIL, a userdata that is truthy and blows up on index.
  local ok, decoded = pcall(vim.json.decode, r.stdout or '')
  if not ok or type(decoded) ~= 'table' or type(decoded.result) ~= 'table' then
    return nil
  end
  local agents = decoded.result.agents
  if type(agents) ~= 'table' then
    return nil
  end

  local want = string.lower(agent)
  local best, best_rank
  for _, a in ipairs(agents) do
    -- never target ourselves: $HERDR_PANE_ID is this nvim's own pane
    if
      type(a) == 'table'
      and a.agent == want
      and type(a.pane_id) == 'string'
      and a.pane_id ~= vim.env.HERDR_PANE_ID
    then
      local rank = (a.tab_id == vim.env.HERDR_TAB_ID and 0 or 1)
        + (a.workspace_id == vim.env.HERDR_WORKSPACE_ID and 0 or 2)
      if not best_rank or rank < best_rank then
        best, best_rank = a.pane_id, rank
      end
    end
  end
  return best
end

-- `agent prompt` submits text and Enter in one call, honouring the pane's live
-- bracketed-paste mode — so it needs none of the tmux buffer dance. No --wait:
-- we hand the prompt over and get out of the way.
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

  -- Fire and forget. vim.fn.system() would block the UI on every edge press for
  -- the round trip to herdr's socket; vim.system() without :wait() does not. We
  -- never read the result — if the pane focus fails there is nothing useful to
  -- do about it, and focus has already visibly not moved.
  focus = function(dir)
    if move_split(dir.wincmd) then
      return
    end
    save_before_leaving()
    vim.system({ 'herdr', 'pane', 'focus', '--direction', dir.name, '--current' })
  end,

  find = herdr_find,
  send = herdr_send,

  -- herdr's `agent prompt` needs a real agent target, so it offers no guess.
  fallback = nil,

  -- herdr-nav.sh relays <M-h/j/k/l> into the pane, so those chords need a
  -- landing pad. See M.setup().
  relay_chord = true,
}

-- ── No multiplexer ─────────────────────────────────────────────────────────
-- Bare terminal. The split motions still want the save-on-switch policy applied
-- for consistency, and there is nothing beyond the edge to move to.
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
  send = function()
    return false
  end,
  fallback = nil,
}

-- ── Detection ──────────────────────────────────────────────────────────────

-- Ordered: herdr first, for both detection and agent delivery.
local adapters = { herdr_adapter, tmux_adapter }

--- Which multiplexer owns the pane this Neovim is running in.
--- Pure: pass any table to ask about that environment instead of this process.
---
--- herdr wins when both are present, preserving what the two separate modules
--- did before (ak/herdr.lua loaded last and overwrote the tmux maps). The
--- nesting it describes — a tmux session inside a herdr pane — is a case where
--- neither set of maps gets a fair hearing anyway: herdr is the OUTER
--- multiplexer, so it consumes ctrl+h first, and herdr-nav.sh sees `tmux` as
--- the pane's foreground process, not nvim, so it focuses the neighbouring
--- herdr pane and the keystroke never reaches Neovim at all. Agent delivery
--- still works in that setup, which is what backends_for() is for.
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
--- A LIST rather than a single pick because "inside herdr" doesn't prove the
--- agents are herdr's: nvim can sit in a tmux session nested inside a herdr
--- pane, with claude/opencode in tmux panes. herdr is asked first, and when it
--- has nothing we fall through instead of hard-failing a setup that worked
--- before.
---
--- Private: see the note on backends() at the top of this file.
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
--- Exists so a caller can bail BEFORE doing expensive or interactive work —
--- ak/agent.lua checks this before prompting you for a question, rather than
--- taking the question and then admitting it has nowhere to send it.
---
--- Not the same question as detect(): a bare `nil` from detect means no
--- multiplexer owns this pane, while this asks whether one is within reach at
--- all. The case where they genuinely diverge is $HERDR_ENV set with neither
--- $HERDR_PANE_ID nor $TMUX — detect() -> nil, reachable() -> true. The full
--- matrix, checked:
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
-- adapter's find/send/fallback fields.
--
-- $<AGENT>_PANE (CLAUDE_PANE, OPENCODE_PANE) pins a destination pane: a tmux
-- target-pane ("%3", "session:win.0") or a herdr pane id ("wF:p6"). The two
-- formats aren't interchangeable, so a pinned target a backend rejects is not
-- fatal — we move on rather than fail on a stale export left in a shell
-- profile. Unset, we go straight to discovery.

--- Get `msg` to `agent`, wherever it is running.
---
--- Three tiers, tried in order: a pinned pane, then discovery, then a guess.
---
--- @param agent string 'Claude', 'OpenCode' — matched case-insensitively
--- @param msg string
--- @param backends table[]|nil adapters to try, nearest first; defaults to the
---        ones reachable from this process. Pass fakes to exercise the ladder
---        without a multiplexer.
--- @return boolean ok
--- @return string|nil err a message to show; nil when the failure was already
---         reported at the point it happened (an adapter notifies its own CLI
---         errors, with the actual stderr, which beats anything we could say
---         about it here)
function M.deliver(agent, msg, backends)
  backends = backends or backends_for(vim.env)
  if #backends == 0 then
    return false, M.no_backend_error
  end

  local env_name = string.upper(agent) .. '_PANE'
  local pinned = vim.env[env_name]

  -- EVERY backend gets a quiet try at the pinned target, not just the nearest
  -- one: with nvim in a tmux session inside a herdr pane both are reachable,
  -- and a $CLAUDE_PANE holding a tmux id is only meaningful to the tmux
  -- adapter — which is never backends[1], since herdr sorts first. Quiet,
  -- because a rejection here is expected and handled, not an error to put in
  -- front of you.
  if pinned then
    for _, backend in ipairs(backends) do
      if backend.send(agent, pinned, msg, true) then
        return true
      end
    end
    vim.notify(
      ('$%s (%s) was rejected; looking for a %s pane instead.'):format(env_name, pinned, agent),
      vim.log.levels.WARN
    )
  end

  for _, backend in ipairs(backends) do
    local target = backend.find(agent)
    if target then
      return backend.send(agent, target, msg)
    end
  end

  -- Nothing found. tmux can still guess "the pane next door"; herdr's
  -- `agent prompt` needs a real agent target, so it offers no guess.
  for _, backend in ipairs(backends) do
    if backend.fallback then
      vim.notify(
        ('No %s pane found; falling back to the next pane. Set $%s to pin one.'):format(agent, env_name),
        vim.log.levels.WARN
      )
      return backend.send(agent, backend.fallback, msg)
    end
  end

  return false, ('No %s agent pane found. Set $%s to pin one.'):format(agent, env_name)
end

-- ── Setup ──────────────────────────────────────────────────────────────────

--- Apply the policy and bind the navigation keys.
---
--- Call this from init.lua. Load order no longer matters: this is the only
--- place in the config that binds <C-h/j/k/l>, so there is no longer a race
--- between a tmux module and a herdr module to bind them last — which is what
--- the ordering comments in init.lua used to be protecting.
function M.setup()
  -- Set unconditionally, including under herdr and in a bare terminal.
  --
  -- `no_mappings` is the load-bearing one: without it, vim-tmux-navigator's
  -- plugin/ file installs its own <C-h/j/k/l> maps when it sources — which
  -- happens AFTER init.lua finishes, so it would clobber whatever we bind
  -- below no matter what order this runs in. The plugin is installed on every
  -- machine this config runs on, so the flag has to be set on every machine.
  --
  -- The rest are read by the plugin at source time and only mean anything under
  -- tmux, but setting them always keeps the policy in one branch-free block.
  vim.g.tmux_navigator_no_mappings = 1
  vim.g.tmux_navigator_save_on_switch = M.policy.save_on_switch and 1 or 0
  vim.g.tmux_navigator_no_wrap = M.policy.no_wrap and 1 or 0
  vim.g.tmux_navigator_disable_when_zoomed = M.policy.disable_when_zoomed and 1 or 0

  local backend = adapter_for(vim.env)
  local map = vim.keymap.set

  -- Normal mode only.
  --
  -- No conflicts with these, checked:
  --   blink.cmp binds <C-h>/<C-l> for snippet jumps — INSERT mode only.
  --   the snacks picker binds <C-h> to edit_split — buffer-local inside the
  --   picker, which correctly shadows navigation while a picker is open.
  --   keymaps.lua binds <A-h/j/k/l> — INSERT mode only, so the relay chords
  --   below don't collide with it.
  for _, dir in ipairs(directions) do
    local handler = function()
      backend.focus(dir)
    end
    local desc = 'Navigate ' .. dir.name .. ' (split or ' .. backend.name .. ' pane)'

    map('n', '<C-' .. dir.wincmd .. '>', handler, { desc = desc })

    -- Under herdr, <M-h/j/k/l> is what actually fires in normal use — it is
    -- the chord herdr-nav.sh relays in. herdr's send-keys writes it straight
    -- into the pane's PTY, so the relay works regardless of how the outer
    -- terminal treats Option; that is why this landing pad predates
    -- `macos-option-as-alt = left` in ghostty/config and does not depend on it.
    --
    -- With that option now set, left Option+h ALSO reaches Neovim as <M-h> and
    -- lands here. Same handler, same result — you just get a second way in.
    if backend.relay_chord then
      map('n', '<M-' .. dir.wincmd .. '>', handler, { desc = desc })
    end
  end
end

return M
