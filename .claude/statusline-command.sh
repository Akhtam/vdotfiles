#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')

CYAN='\033[36m'; YELLOW='\033[33m'; RESET='\033[0m'

BRANCH=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH=" |  $(git branch --show-current 2>/dev/null)"

LIMIT=""
[ -n "$FIVE_H" ] && LIMIT=" | ${YELLOW}5h ${FIVE_H%.*}%${RESET}"

MODEL_LABEL="$MODEL"
[ -n "$EFFORT" ] && MODEL_LABEL="$MODEL:$EFFORT"

echo -e "🗂️ ${DIR##*/}$BRANCH | ${CYAN}[$MODEL_LABEL]${RESET}${LIMIT}"
