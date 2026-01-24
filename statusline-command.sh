#!/bin/bash

define_colors() {
    dim="\033[0;90m"
    cyan="\033[0;36m"
    magenta="\033[0;35m"
    yellow="\033[0;33m"
    green="\033[0;32m"
    orange="\033[0;38;5;208m"
    red="\033[0;31m"
    reset="\033[0m"
    sep="${dim} • ${reset}"
}

read_input_from_stdin() {
    input=$(cat)
}

extract_directory_name() {
    cwd=$(echo "$input" | jq -r '.workspace.current_dir')
}

find_git_root() {
    git_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$git_root" ]; then
        dir_name=$(basename "$git_root")
    else
        git_root="$cwd"
        dir_name=$(basename "$cwd")
    fi
}

extract_model_name() {
    model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
}

calculate_context_usage_percent() {
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
    else
        percent=-1
    fi
}

select_bar_and_color_for_percent() {
    local pct=$1

    if [ "$pct" -lt 13 ]; then
        bar="▁"; color="$green"
    elif [ "$pct" -lt 25 ]; then
        bar="▂"; color="$green"
    elif [ "$pct" -lt 38 ]; then
        bar="▃"; color="$yellow"
    elif [ "$pct" -lt 50 ]; then
        bar="▄"; color="$yellow"
    elif [ "$pct" -lt 63 ]; then
        bar="▅"; color="$orange"
    elif [ "$pct" -lt 75 ]; then
        bar="▆"; color="$orange"
    elif [ "$pct" -lt 88 ]; then
        bar="▇"; color="$red"
    else
        bar="█"; color="$red"
    fi
}

format_context_info() {
    calculate_context_usage_percent

    if [ "$percent" -ge 0 ]; then
        select_bar_and_color_for_percent "$percent"
        context_info=$(printf "${color}%s %d%%${reset}" "$bar" "$percent")
    else
        context_info="--"
    fi
}

read_sandbox_status_from_settings() {
    local settings_local="${git_root}/.claude/settings.local.json"
    local settings_default="${git_root}/.claude/settings.json"
    local settings_file=""

    if [ -f "$settings_local" ]; then
        settings_file="$settings_local"
    elif [ -f "$settings_default" ]; then
        settings_file="$settings_default"
    fi

    if [ -n "$settings_file" ]; then
        sandbox_enabled=$(jq -r '.sandbox.enabled // false' "$settings_file" 2>/dev/null)
        if [ "$sandbox_enabled" = "true" ]; then
            sandbox_info=$(printf "${green}◉ sbox${reset}")
        else
            sandbox_info=$(printf "${red}○ sbox${reset}")
        fi
    else
        sandbox_info=$(printf "${dim}? sbox${reset}")
    fi
}

get_git_branch_with_dirty_indicator() {
    if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
        branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

        if git -C "$cwd" -c core.useReplaceRefs=false diff-index --quiet HEAD -- 2>/dev/null; then
            git_info=$(printf "${magenta}%s${reset}" "$branch")
        else
            git_info=$(printf "${magenta}%s${yellow}*${reset}" "$branch")
        fi
    else
        git_info=""
    fi
}

build_statusline_output() {
    output=$(printf "${cyan}%s${reset}" "$dir_name")

    if [ -n "$git_info" ]; then
        output="${output}${sep}${git_info}"
    fi

    output="${output}${sep}${dim}${model}${reset}${sep}${context_info}${sep}${sandbox_info}"
}

main() {
    define_colors
    read_input_from_stdin
    extract_directory_name
    find_git_root
    extract_model_name
    format_context_info
    read_sandbox_status_from_settings
    get_git_branch_with_dirty_indicator
    build_statusline_output
    printf "%b" "$output"
}

main
