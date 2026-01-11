# Claude Code Configuration

Custom configuration files for [Claude Code](https://claude.ai/code).

## Statusline

A custom statusline script that displays:

- **Directory** (cyan) - Current working directory name
- **Git branch** (magenta) - Current branch with `*` indicator for uncommitted changes
- **Model** (dim) - Active Claude model
- **Context usage** - Visual bar with color gradient:
  - Green (0-25%)
  - Yellow (25-50%)
  - Orange (50-75%)
  - Red (75-100%)
- **Sandbox status** - Indicator showing sandbox state:
  - `◉ sbox` (green) - Sandbox enabled
  - `○ sbox` (red) - Sandbox disabled
  - `? sbox` (dim) - No settings file found

Example output: `my-project • master* • Opus 4.5 • ▃ 32% • ◉ sbox`

## Installation

1. Copy the statusline script to your Claude config directory:

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

2. Add the following to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

3. Restart Claude Code to see the new statusline.

## Requirements

- `jq` - For parsing JSON input
- `git` - For branch information (optional)
