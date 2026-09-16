#!/usr/bin/env bash
#
# install.sh — put this repo's configs where their programs look for them.
#
# The repo says what every config CONTAINS. Until this file existed it did not
# say where any of them GOES: that lived only as symlinks on one machine, made
# by hand over 19 months, and it showed — of the fourteen links pointing into
# this repo, four were BROKEN (three lazy.nvim-era paths under ~/.config, plus
# ~/.claude/settings.local.json, which names a file that has never existed
# here), ~/.config/nvim had a duplicate at ~/.config/nvim.bak, and five more sat
# directly in $HOME where nothing reads them. None of that was visible from the
# repo, and nothing could have told you.
#
#   ./install.sh            link everything, then report anything suspicious
#   ./install.sh --brew     also run `brew bundle` against .config/Brewfile
#   ./install.sh --prune    also delete BROKEN links that point into this repo
#   ./install.sh --check    report only; make no changes at all
#
# Running it on a fresh machine is the test. Re-running it on a configured one
# is a no-op — every step is idempotent — which is what makes it safe to run
# whenever you add a config.
#
# ── Granularity ────────────────────────────────────────────────────────────
# Two kinds of entry, and the rule for choosing is not stylistic:
#
#   whole directory — the program's config dir is ours end to end (nvim)
#   single file     — the program also writes state into that directory that
#                     must NOT be in the repo: herdr's session.json and logs,
#                     bat's compiled theme cache. Linking the directory would either drag that
#                     into git or put the repo where the program writes.
#
# When you add a config, add its line here in the same commit. --check will
# tell you if you forget: it walks every tracked file and reports any that no
# entry below accounts for.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── The mapping ────────────────────────────────────────────────────────────
# repo-relative path                              path under $HOME
LINKS='
.zshrc                                            .zshrc
.tmux.conf                                        .tmux.conf
.config/nvim                                      .config/nvim
.config/Brewfile                                  .config/Brewfile
.config/lsd/config.yaml                           .config/lsd/config.yaml
.config/ghostty/config                            .config/ghostty/config
.config/bat/themes/tokyonight_night.tmTheme       .config/bat/themes/tokyonight_night.tmTheme
.config/lazygit/config.yml                        Library/Application Support/lazygit/config.yml
.config/lazydocker/config.yml                     Library/Application Support/jesseduffield/lazydocker/config.yml
.config/herdr/config.toml                         .config/herdr/config.toml
.claude/statusline-command.sh                     .claude/statusline-command.sh
'
# Deliberately absent: .claude/settings.local.json. ~/.claude/settings.local.json
# is a symlink into this repo, but the file it points at has never existed here
# — `**/.claude/settings.local.json` is ignored globally via ~/.config/git/ignore,
# so it could not be committed even if it were. The link is a dead end; the
# stale-link check below reports it, and --prune removes it.

# Tracked files that are deliberately NOT linked anywhere, so --check stays
# quiet about them.
#
#   herdr-nav.sh   herdr runs these by absolute repo path — see the
#   herdr-battery.sh  [[keys.command]] blocks and the status command in
#                  .config/herdr/config.toml. Linking them would give the same
#                  script two names for no gain.
#   install.sh     this file.
#   nvim internals covered by the .config/nvim directory link above.
EXEMPT='
.config/herdr/herdr-nav.sh
.config/herdr/herdr-battery.sh
install.sh
'

do_brew=0
do_prune=0
check_only=0
for arg in "$@"; do
  case "$arg" in
    --brew)  do_brew=1 ;;
    --prune) do_prune=1 ;;
    --check) check_only=1 ;;
    # Print the banner: every comment line between the shebang and the first
    # line of code. Derived, not a line range — a hard-coded range silently
    # truncates the help the moment the banner grows, which it already did once.
    -h|--help) sed -e '1d' -e '/^[^#]/,$d' -e 's/^#\{0,1\} \{0,1\}//' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "install.sh: unknown option '$arg'" >&2; exit 2 ;;
  esac
done

warnings=0
say()  { printf '%s\n' "$*"; }
ok()   { printf '  ok      %s\n' "$*"; }
did()  { printf '  linked  %s\n' "$*"; }
warn() { printf '  WARN    %s\n' "$*"; warnings=$((warnings + 1)); }

# Iterate the mapping. Callers get "$src" and "$dst" per row.
each_link() {
  while read -r src dst; do
    [ -n "$src" ] || continue
    "$1" "$src" "$dst"
  done <<< "$LINKS"
}

# ── Linking ────────────────────────────────────────────────────────────────
install_one() {
  local src="$1" dst="$2"
  local from="$REPO/$src" to="$HOME/$dst"

  if [ ! -e "$from" ]; then
    warn "$src is in the mapping but not in the repo"
    return
  fi

  # Already correct? Say nothing new and touch nothing.
  if [ -L "$to" ] && [ "$(realpath "$to" 2>/dev/null)" = "$(realpath "$from")" ]; then
    ok "$dst"
    return
  fi

  # A real file or directory in the way is never overwritten automatically —
  # that is someone's config, and it may be the only copy.
  if [ -e "$to" ] && [ ! -L "$to" ]; then
    warn "$dst exists and is not a symlink — move it aside, then re-run"
    return
  fi

  if [ "$check_only" = 1 ]; then
    warn "$dst is not linked (run without --check to fix)"
    return
  fi

  mkdir -p "$(dirname "$to")"
  # -n so an existing symlink-to-a-directory is replaced rather than followed,
  # which would nest the link inside the directory it already points at.
  ln -sfn "$from" "$to"
  did "$dst"
}

# ── Coverage check ─────────────────────────────────────────────────────────
# Every tracked file should be reachable through one of the entries above.
# This is what catches a config added to the repo and never deployed.
emit_src() { printf '%s\n' "$1"; }
emit_dst() { printf '%s\n' "$HOME/$2"; }

link_sources() { each_link emit_src; }
link_dests()   { each_link emit_dst; }

check_coverage() {
  local sources exempt path covered
  sources="$(link_sources)"
  exempt="$(printf '%s\n' "$EXEMPT" | sed '/^$/d')"

  while IFS= read -r path; do
    covered=0
    while IFS= read -r src; do
      case "$path" in
        "$src"|"$src"/*) covered=1; break ;;
      esac
    done <<< "$sources"
    if [ "$covered" = 0 ]; then
      while IFS= read -r ex; do
        if [ "$path" = "$ex" ]; then
          covered=1
          break
        fi
      done <<< "$exempt"
    fi
    if [ "$covered" = 0 ]; then
      warn "tracked but never linked anywhere: $path"
    fi
  done < <(cd "$REPO" && git ls-files)
  return 0
}

# ── Stale-link check ───────────────────────────────────────────────────────
# Symlinks that point into this repo but are not part of the mapping: either
# broken (the repo path is gone) or stray (a real target, in a place nothing
# reads). Both are leftovers from linking by hand.
check_stale() {
  local wanted link target short abs dir base
  wanted="$(link_dests)"

  while IFS= read -r link; do
    target="$(readlink "$link")"

    # Resolve the target to an absolute path and test it against $REPO, rather
    # than string-matching "dotfiles" anywhere in it — a link to some unrelated
    # ~/src/dotfiles-backup/ is not ours to report on. The target is usually
    # relative to the link's own directory, so resolve it from there. `cd` on
    # the PARENT works even for a broken link, since it is the leaf that is
    # missing; if even the parent is gone, we cannot classify it and move on.
    dir="$(dirname "$target")"
    base="$(basename "$target")"
    case "$dir" in
      /*) ;;
      *) dir="$(dirname "$link")/$dir" ;;
    esac
    abs="$(cd "$dir" 2>/dev/null && pwd)" || abs=''
    if [ -z "$abs" ]; then
      continue
    fi
    abs="$abs/$base"

    case "$abs" in "$REPO"/*) ;; *) continue ;; esac
    if grep -qxF "$link" <<< "$wanted"; then
      continue
    fi

    short="~${link#"$HOME"}"

    if [ ! -e "$link" ]; then
      if [ "$do_prune" = 1 ] && [ "$check_only" = 0 ]; then
        rm "$link"
        printf '  pruned  %s (was -> %s)\n' "$short" "$target"
      else
        warn "broken link $short -> $target  (--prune removes it)"
      fi
    else
      # Resolves fine, just not somewhere anything looks. Never removed
      # automatically: it is a working link and only you know if something
      # depends on it.
      warn "stray link $short -> $target  (not in the mapping; delete by hand if unused)"
    fi
  done < <(
    find "$HOME" -maxdepth 1 -type l 2>/dev/null
    find "$HOME/.config" "$HOME/.claude" -maxdepth 2 -type l 2>/dev/null
  )
  return 0
}

# ── Run ────────────────────────────────────────────────────────────────────
say "links"
each_link install_one

if [ "$check_only" = 0 ]; then
  # bat reads themes from a compiled cache, not from the theme file directly,
  # so a freshly linked .tmTheme does nothing until this runs. Idempotent.
  if command -v bat >/dev/null 2>&1; then
    bat cache --build >/dev/null 2>&1 && ok "bat theme cache rebuilt"
  fi

  if [ "$do_brew" = 1 ]; then
    say ""
    say "brew bundle"
    brew bundle --file "$REPO/.config/Brewfile"
  fi
fi

say ""
say "checks"
check_coverage
check_stale

if [ "$warnings" -eq 0 ]; then
  say ""
  say "clean."
else
  say ""
  say "$warnings warning(s) above."
fi
