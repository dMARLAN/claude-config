#!/bin/bash

# Read input from stdin
input=$(cat)

# Colors
dim="\033[0;90m"
cyan="\033[0;36m"
magenta="\033[0;35m"
yellow="\033[0;33m"
reset="\033[0m"

# Separator
sep="${dim} • ${reset}"

# Get current directory from input
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
dir_name=$(basename "$cwd")

# Get model name
model=$(echo "$input" | jq -r '.model.display_name // "unknown"')

# Get context window usage
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
if [ "$context_size" -gt 0 ]; then
    current_usage=$(echo "$input" | jq -r '.context_window.current_usage')
    if [ "$current_usage" != "null" ]; then
        input_tokens=$(echo "$current_usage" | jq -r '.input_tokens // 0')
        cache_creation=$(echo "$current_usage" | jq -r '.cache_creation_input_tokens // 0')
        cache_read=$(echo "$current_usage" | jq -r '.cache_read_input_tokens // 0')
        total_tokens=$((input_tokens + cache_creation + cache_read))
        percent=$((total_tokens * 100 / context_size))
    else
        percent=0
    fi

    # Visual bar (8 levels) + color gradient
    if [ "$percent" -lt 13 ]; then
        bar="▁"; color="\033[0;32m"
    elif [ "$percent" -lt 25 ]; then
        bar="▂"; color="\033[0;32m"
    elif [ "$percent" -lt 38 ]; then
        bar="▃"; color="\033[0;33m"
    elif [ "$percent" -lt 50 ]; then
        bar="▄"; color="\033[0;33m"
    elif [ "$percent" -lt 63 ]; then
        bar="▅"; color="\033[0;38;5;208m"
    elif [ "$percent" -lt 75 ]; then
        bar="▆"; color="\033[0;38;5;208m"
    elif [ "$percent" -lt 88 ]; then
        bar="▇"; color="\033[0;31m"
    else
        bar="█"; color="\033[0;31m"
    fi
    context_info=$(printf "${color}%s %d%%${reset}" "$bar" "$percent")
else
    context_info="--"
fi

# Check if we're in a git repo and get branch info
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

    # Check for uncommitted changes
    if git -C "$cwd" -c core.useReplaceRefs=false diff-index --quiet HEAD -- 2>/dev/null; then
        git_info=$(printf "${magenta}%s${reset}" "$branch")
    else
        git_info=$(printf "${magenta}%s${yellow}*${reset}" "$branch")
    fi
else
    git_info=""
fi

# Build output: dir • branch • model • context
output=$(printf "${cyan}%s${reset}" "$dir_name")

if [ -n "$git_info" ]; then
    output="${output}${sep}${git_info}"
fi

output="${output}${sep}${dim}${model}${reset}${sep}${context_info}"

printf "%b" "$output"
