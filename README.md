# claude-env

**Safely backup, swap, and restore your entire Claude Code environment.**

Claude Code stores everything under `~/.claude/` — rules, skills, agents, commands, hooks, plugins, settings, session history, and more. It's the accumulated result of weeks or months of customization. There's no built-in way to snapshot it, swap to a clean slate, or roll back.

`claude-env` fixes that. It backs up **everything** in `~/.claude/` and only excludes what you tell it to keep (credentials and MCP by default).

## The Problem

You want to try a new agentic framework that integrates with Claude Code. Or you want to start fresh. But `~/.claude/` is a complex directory that changes over time — Claude Code adds new files, plugins create caches, skills install subdirectories. Any backup tool that lists specific files to include will silently miss things.

`claude-env` takes the opposite approach: **backup everything, exclude only what you name.**

## Quick Start

```bash
# Save your current environment
claude-env backup my-setup

# Your ~/.claude/ is now clean — only credentials and MCP configs remain.
# Claude Code will feel like a fresh install.

# Don't like the new setup? Come back in one command:
claude-env restore my-setup
```

## Installation

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/rmdes/claude-env/main/install.sh | bash
```

This downloads `claude-env` to `~/.local/bin/`. Override with `INSTALL_DIR`:

```bash
INSTALL_DIR=/usr/local/bin sudo -E bash -c "$(curl -fsSL https://raw.githubusercontent.com/rmdes/claude-env/main/install.sh)"
```

### Manual

```bash
curl -fsSL https://raw.githubusercontent.com/rmdes/claude-env/main/claude-env -o ~/.local/bin/claude-env
chmod +x ~/.local/bin/claude-env
```

### Requirements

- Bash 4.4+
- Standard Unix tools (cp, rm, diff, du, date, grep, sed)
- No Python, no Node, no jq.

## How It Works

### Exclude-based model

`claude-env` copies **every file and directory** in `~/.claude/` into the backup, except items on the exclude list. By default, only two things are excluded:

| Excluded by default | Why |
|---|---|
| `.credentials.json` | You don't want credentials in backups |
| `mcp-servers/`, `.mcp.json` | MCP server configs are shared across environments |

This means if Claude Code creates a new directory tomorrow (say `~/.claude/workflows/`), it gets backed up automatically. No script update needed.

### Flags

| Flag | Effect |
|------|--------|
| `--no-reset` | Backup without deleting anything (snapshot only) |
| `--include-mcp` | Also backup MCP configs (normally excluded) |
| `--include-credentials` | Also backup credentials (normally excluded) |
| `--exclude <path>` | Exclude an additional path (repeatable) |
| `--force` | Overwrite existing backup / skip auto-backup on restore |
| `--dry-run` | Preview what would happen |
| `--verbose` | Show every file operation |

### Manifests

Every backup writes a `manifest.json`:

```json
{
  "version": 2,
  "created": "2026-04-08T20:00:00Z",
  "name": "my-setup",
  "backed_up": ["rules", "skills", "agents", "plugins", "settings.json", "..."],
  "excluded": [".credentials.json", "mcp-servers", ".mcp.json"],
  "claude_dir": "/home/you/.claude"
}
```

## Commands

### `backup [name]`

Backs up everything, then resets (removes backed-up items from `~/.claude/`).

```bash
claude-env backup my-setup              # Backup + reset
claude-env backup                       # Auto-named with timestamp
claude-env backup my-setup --no-reset   # Snapshot only, keep working
claude-env backup --include-mcp full    # Include MCP configs too
claude-env backup --exclude projects s  # Skip projects/ (session history)
claude-env backup my-setup --dry-run    # Preview
```

### `restore <name>`

Restores a backup into `~/.claude/`. Automatically saves current state first.

```bash
claude-env restore my-setup             # Restore (auto-saves current state)
claude-env restore my-setup --force     # Skip the auto-save
claude-env restore my-setup --dry-run   # Preview
```

### `list`

Shows all available backups.

```bash
claude-env list
```

### `diff <name>`

Compares a backup against current `~/.claude/` — shows identical, modified, added, removed items.

```bash
claude-env diff my-setup
```

**Symbols:**
- `✓` — identical
- `~` — modified
- `+` — only in backup (you lost something)
- `-` — only in current (something new)

## Global Flags

Go **before** the subcommand:

```bash
claude-env --dry-run backup my-setup
claude-env --verbose restore my-setup
claude-env --dir /mnt/usb/backups list
claude-env --claude-dir /other/.claude diff my-setup
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CLAUDE_DIR` | Path to Claude config directory | `~/.claude` |
| `BACKUP_DIR` | Path to backup storage | `~/.claude-backups` |
| `NO_COLOR` | Disable colored output | unset |

## Common Workflows

### Testing a new framework

```bash
claude-env backup before-experiment
# Install the new thing...
# Don't like it?
claude-env restore before-experiment
```

### Snapshot without resetting

```bash
claude-env backup checkpoint --no-reset
```

### Exclude large dirs you don't need

```bash
claude-env backup light --exclude projects --exclude plugins
```

### Sharing a setup

```bash
claude-env backup team-baseline --no-reset
cp -r ~/.claude-backups/team-baseline /shared/drive/
# On another machine:
cp -r /shared/drive/team-baseline ~/.claude-backups/
claude-env restore team-baseline
```

## FAQ

**Q: Why not list specific files to backup?**

Because Claude Code evolves. Skills, agents, plugins, and other components get added over time. A hardcoded list silently misses new items. The exclude-based model catches everything by default.

**Q: What if I restore and something goes wrong?**

Every `restore` auto-creates a `pre-restore-*` backup first. You can always undo.

**Q: Does it work on macOS/Linux?**

Yes. Pure Bash with standard Unix tools. macOS ships Bash 3.2, so you may need `brew install bash`.

## Contributing

```bash
npx bats tests/claude-env.bats   # 38 tests
```

Tests use [BATS](https://github.com/bats-core/bats-core) with isolated temp directories — they never touch your real `~/.claude/`.

## License

[MIT](LICENSE)
