#!/bin/sh
# herdr-nav.sh — the herdr half of seamless <C-h/j/k/l> navigation.
#
# This is what vim-tmux-navigator's tmux half does, reimplemented in ~20 lines
# because herdr has no such plugin. herdr binds ctrl+h/j/k/l to this script
# (see [[keys.command]] in config.toml). On each press we ask: is the focused
# pane running (n)vim?
#
#   yes -> relay the keystroke into the pane and let Neovim decide whether to
#          move between its own splits or bounce back out to a herdr pane
#          (lua/ak/mux.lua handles that edge case).
#   no  -> just focus the neighbouring herdr pane.
#
# WHY WE RELAY alt+h INSTEAD OF ctrl+h
# ------------------------------------
# Relaying the *same* chord we are bound to risks an infinite loop: if
# `pane send-keys` re-entered herdr's keybinding layer, ctrl+h would retrigger
# this script forever. Sending a chord that herdr does NOT bind makes that loop
# impossible by construction rather than by timing guard. Neovim maps both
# <M-h> and <C-h> to the same function, so the relay is invisible to you.
#
# Usage: herdr-nav.sh <left|down|up|right>

set -eu

dir="$1"

# The relay chord per direction. Derived here rather than passed in as a second
# argument, so the direction and the key it relays cannot drift apart across
# four near-identical [[keys.command]] blocks in config.toml.
case "$dir" in
  left)  relay_key="alt+h" ;;
  down)  relay_key="alt+j" ;;
  up)    relay_key="alt+k" ;;
  right) relay_key="alt+l" ;;
  *)     echo "herdr-nav.sh: unknown direction '$dir'" >&2; exit 2 ;;
esac

# Resolve the focused pane by asking the server, NOT via --current. This script
# is spawned detached by herdr, so it has no $HERDR_PANE_ID of its own and
# --current would fail to resolve.
pane=$(herdr pane list | jq -r '.result.panes[] | select(.focused) | .pane_id')
[ -n "$pane" ] || exit 0

# The (n)vim test. Same process-name matching vim-tmux-navigator uses, against
# the pane's foreground process group.
if herdr pane process-info --pane "$pane" \
  | jq -e '.result.process_info.foreground_processes[]?
           | select(.name | test("^(view|n?vim(diff)?)$"))' >/dev/null 2>&1
then
  herdr pane send-keys "$pane" "$relay_key"
else
  herdr pane focus --direction "$dir" --pane "$pane"
fi
