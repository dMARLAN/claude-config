#!/bin/bash

define_colors() {
    dim="\033[0;90m"
    cyan="\033[0;36m"
    magenta="\033[0;35m"
    yellow="\033[0;33m"
    green="\033[0;32m"
    orange="\033[0;38;5;208m"
    red="\033[0;31m"
    blue="\033[0;34m"
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

format_session_info() {
    local session_id peer_name
    session_id=$(echo "$input" | jq -r '.session_id // empty')

    if [ -z "$session_id" ]; then
        session_info=""
        return
    fi

    peer_name=$(jq -rs --arg id "$session_id" \
        'map(select(.sessionId == $id)) | max_by(.updatedAt) | .name // empty' \
        "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/sessions/*.json 2>/dev/null)

    if [ -n "$peer_name" ]; then
        session_info=$(printf "${blue}%s${reset} ${dim}%s${reset}" "$peer_name" "${session_id:0:8}")
    else
        session_info=$(printf "${dim}%s${reset}" "${session_id:0:8}")
    fi
}

extract_model_name() {
    model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
    model_id=$(echo "$input" | jq -r '.model.id // empty')
}

format_model_label() {
    case "$model_id $model" in
        *[Ff]able*)  model_label=$(printf "\033[1;38;5;16;48;5;141m ✦ %s ${reset}" "$model") ;;
        *[Oo]pus*)   model_label=$(printf "\033[1;38;5;173m◆ %s${reset}" "$model") ;;
        *[Ss]onnet*) model_label=$(printf "\033[0;38;5;75m◇ %s${reset}" "$model") ;;
        *[Hh]aiku*)  model_label=$(printf "\033[0;38;5;114m· %s${reset}" "$model") ;;
        *)           model_label=$(printf "${dim}%s${reset}" "$model") ;;
    esac
}

format_effort_level() {
    effort=$(echo "$input" | jq -r '.effort.level // empty')

    case "$effort" in
        low)    effort_info=$(printf "${dim}○ low${reset}") ;;
        medium) effort_info=$(printf "${green}◔ medium${reset}") ;;
        high)   effort_info=$(printf "${yellow}◑ high${reset}") ;;
        xhigh)  effort_info=$(printf "${orange}◕ xhigh${reset}") ;;
        max)    effort_info=$(printf "${red}● max${reset}") ;;
        *)      effort_info="" ;;
    esac
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
    local settings_file="${git_root}/.claude/settings.local.json"

    if [ -f "$settings_file" ]; then
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

    output="${output}${sep}${model_label}"

    if [ -n "$effort_info" ]; then
        output="${output} ${effort_info}"
    fi

    output="${output}${sep}${context_info}${sep}${sandbox_info}"

    if [ -n "$session_info" ]; then
        output="${output}${sep}${session_info}"
    fi
}

main() {
    define_colors
    read_input_from_stdin
    extract_directory_name
    find_git_root
    extract_model_name
    format_model_label
    format_effort_level
    format_context_info
    read_sandbox_status_from_settings
    get_git_branch_with_dirty_indicator
    format_session_info
    build_statusline_output
    printf "%b" "$output"
}

main
