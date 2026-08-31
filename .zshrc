# ~/.zshrc
#
# What used to be here: oh-my-zsh's install template, ~90 lines of commented-out
# settings shipped with the framework. They documented options this shell does
# not set, and the ~60 lines that are actually configuration were scattered
# through them — as was the duplication, which is hard to see against a
# background of dead text. The template is upstream's documentation, not this
# machine's config; `less $ZSH/templates/zshrc.zsh-template` still has it.

# ── Environment ────────────────────────────────────────────────────────────
# One editor, stated once. `git commit`, lazygit, and the fzf helpers below all
# read $EDITOR, so this is the single place that decides which one opens.
export EDITOR="nvim"
export VISUAL="$EDITOR"

# Read by `bat` — and it must be EXPORTED to be read at all, since bat is a
# child process and plain shell variables aren't inherited. The theme file
# itself is ~/.dotfiles/.config/bat/themes/tokyonight_night.tmTheme, linked into
# place by install.sh; `bat cache --build` is what registers it.
export BAT_THEME="tokyonight_night"

# ── PATH ───────────────────────────────────────────────────────────────────
# Assembled in one block. Each line PREPENDS, so the last line listed wins —
# the order below reads lowest-priority first.
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# pnpm's global bin. The case guard is pnpm's own generated snippet, kept
# because it makes re-sourcing this file idempotent.
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac

# ── oh-my-zsh ──────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git)
source $ZSH/oh-my-zsh.sh

# Two-line prompt: agnoster's segments on the first line, the cursor on its own
# line below, so a long path never leaves you typing in the last few columns.
# Must come AFTER oh-my-zsh.sh, which is where agnoster sets PROMPT.
PROMPT=$'\n%{%f%b%k%}╭─ $(build_prompt)\n╰─> '
RPROMPT=''
# Drop agnoster's `user@host` segment — it costs a third of the prompt to tell
# you something that never changes on a single-user laptop.
prompt_context() {}

# ── fzf ────────────────────────────────────────────────────────────────────
# fd rather than find: respects .gitignore by default and is faster on large
# trees. --strip-cwd-prefix keeps results as relative paths.
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Path/directory candidate generators for fzf's completion. $1 is the base path
# to start traversal from — see fzf's completion.zsh for the contract.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}

# Directories get a tree, files get syntax-highlighted head.
show_file_or_dir_preview="if [ -d {} ]; then lsd --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

# "Open the highlighted result in the editor", spelled once and referenced by
# every fzf invocation below. It used to be six copies of the same string —
# four of which said `vim` while the rest of this file said nvim, so the key did
# something subtly different depending on which fzf you were in.
fzf_open_bind="ctrl-v:execute($EDITOR {})"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview' --bind '$fzf_open_bind'"
export FZF_ALT_C_OPTS="--preview 'lsd --tree --color=always {} | head -200' --bind '$fzf_open_bind'"

# Per-command fzf behaviour: `cd **<TAB>` gets a tree preview, `ssh **<TAB>`
# gets a DNS lookup, everything else gets the file/dir preview.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview 'lsd --tree --color=always {} | head -200' --bind "$fzf_open_bind" "$@" ;;
    export|unset) fzf --preview "eval 'echo ${}'" --bind "$fzf_open_bind" "$@" ;;
    ssh)          fzf --preview 'dig {}' --bind "$fzf_open_bind" "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" --bind "$fzf_open_bind" "$@" ;;
  esac
}

# Grep the tree with ripgrep, pick a hit with fzf, open it at that line.
# Bound to `rgf` below.
fzf_rg() {
  local query="$1"

  # If no query is provided, prompt for one.
  if [[ -z "$query" ]]; then
    query=$(echo "" | fzf --prompt="Enter regex: " --header="Search files with regex" --print-query)
    [[ -z "$query" ]] && return
  fi

  rg --color=always --line-number "$query" |
    fzf --ansi \
        --delimiter=":" \
        --preview="bat --color=always --style=numbers --highlight-line {2} {1}" \
        --preview-window="60%" \
        --bind="enter:execute($EDITOR {1} +{2})"
}

# ── Aliases ────────────────────────────────────────────────────────────────
alias bx="bundle exec"
alias ls="lsd"
alias lt="lsd --tree"
alias rgf="fzf_rg"
alias vm="nvim"
alias py="python3"
alias oc="opencode"
alias clc="claude"
alias pn="pnpm"
alias hra="herdr session attach"
alias hr='herdr'
alias lg='lazygit'
alias ld='lazydocker'
# ── Completion ─────────────────────────────────────────────────────────────
# fzf's key bindings (CTRL-T, CTRL-R, ALT-C) and fuzzy completion.
source <(fzf --zsh)

# Added by Docker Desktop. compinit has to run after fpath is final.
fpath=($HOME/.docker/completions $fpath)
autoload -Uz compinit
compinit

# Inline suggestions from command history.
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
