# claude-env

**Safely backup, swap, and restore your entire Claude Code environment.**

Claude Code stores everything under `~/.claude/` — your rules, skills, agents, commands, hooks, plugins, settings, MCP servers, and credentials. It's the accumulated result of weeks or months of customization. There's no built-in way to snapshot it, swap to a clean slate, or roll back.

`claude-env` fixes that. It treats your Claude Code config as a set of **layers** (customizations, config, plugins, credentials, MCP) and lets you back up, reset, restore, and compare them independently.

## The Problem

You want to try a new agentic framework that integrates with Claude Code. Or you want to start fresh with a minimal setup. Or you need different configurations for different projects. But `~/.claude/` is a mix of:

- **Your work** — rules you wrote, skills you installed, agents you configured, settings you tuned
- **Runtime noise** — session logs, caches, telemetry, debug output, temp files

Deleting `~/.claude/` is a nuclear option. Manually copying files is error-prone. You need to know which files matter and which are disposable.

`claude-env` knows the difference. It backs up what matters, ignores what doesn't, and gives you a clean swap.

## Quick Start

```bash
# Save your current environment
claude-env backup my-setup

# Your ~/.claude/ is now clean — only credentials and MCP configs remain
# Go ahead and test that new framework, install new plugins, etc.

# Don't like it? Come back in one command:
claude-env restore my-setup
```

That's it. Your rules, skills, agents, commands, hooks, plugins, and settings are all back exactly as they were.

## Installation

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/ricklamers/claude-env/main/install.sh | bash
```

This downloads `claude-env` to `~/.local/bin/`. Override with `INSTALL_DIR`:

```bash
INSTALL_DIR=/usr/local/bin sudo -E bash -c "$(curl -fsSL https://raw.githubusercontent.com/ricklamers/claude-env/main/install.sh)"
```

### Manual

```bash
curl -fsSL https://raw.githubusercontent.com/ricklamers/claude-env/main/claude-env -o ~/.local/bin/claude-env
chmod +x ~/.local/bin/claude-env
```

Make sure `~/.local/bin` is in your `PATH`.

### Requirements

- Bash 4.4+
- Standard Unix tools (cp, rm, diff, du, date, grep, sed)
- No other dependencies. No Python, no Node, no jq.

## How It Works

### Layers

`claude-env` organizes `~/.claude/` into six layers:

| Layer | What's in it | Default behavior |
|-------|-------------|-----------------|
| **customizations** | `rules/`, `skills/`, `commands/`, `agents/`, `hooks/`, `CLAUDE.md` | Backup + reset |
| **config** | `settings.json`, `settings.local.json`, `statusline.sh`, Sisyphus/Pilot config files | Backup + reset |
| **plugins** | `plugins/installed_plugins.json`, `plugins/config.json`, `plugins/known_marketplaces.json`, `plugins/local/`, `plugins/data/` | Backup + reset |
| **integrations** | (reserved for future use) | Backup + reset |
| **credentials** | `.credentials.json` | **Keep** (never touched unless you opt in) |
| **mcp** | `mcp-servers/`, `.mcp.json` | **Keep** (never touched unless you opt in) |

**"Backup + reset"** means: the files are copied to the backup, then removed from `~/.claude/`. You get a clean slate for that layer.

**"Keep"** means: the files stay in `~/.claude/` and are NOT included in the backup. Your API credentials and MCP server configs survive across environment swaps.

### What's NOT backed up (by design)

These are ephemeral runtime files that regenerate automatically:

- `sessions/` — conversation transcripts
- `projects/` — per-project permission caches
- `todos/`, `tasks/` — session-scoped task lists
- `cache/`, `plugins/cache/`, `plugins/repos/` — download caches
- `backups/` — Claude Code's own internal backups
- `debug/`, `telemetry/`, `statsig/` — debug logs and telemetry
- `history.jsonl` — command history
- `file-history/`, `session-env/`, `shell-snapshots/`, `paste-cache/` — various caches
- `security_warnings_state_*.json` — security prompt state
- `ide/` — IDE integration state

### Manifests

Every backup writes a `manifest.json` that records what was backed up:

```json
{
  "version": 1,
  "created": "2026-04-06T14:30:00Z",
  "name": "my-setup",
  "layers": ["customizations", "config", "plugins"],
  "kept": ["credentials", "mcp"],
  "claude_dir": "/home/you/.claude"
}
```

This manifest is how `restore`, `list`, and `diff` know what layers a backup contains.

## Commands

### `backup [name]`

Creates a snapshot of your Claude Code environment. By default, it backs up the customizations, config, plugins, and integrations layers, then **resets** them (removes them from `~/.claude/`). Credentials and MCP are kept in place.

```bash
# Backup with a name you'll remember
claude-env backup my-setup

# Auto-generated timestamp name (2026-04-06T14-30-00)
claude-env backup

# Backup WITHOUT resetting — just take a snapshot, keep working
claude-env backup my-setup --no-reset

# Preview what would happen without doing anything
claude-env backup my-setup --dry-run
```

**Layer control flags:**

```bash
# Also backup (and reset) your MCP server configs
claude-env backup my-setup --include-mcp

# Also backup (and reset) your credentials
claude-env backup my-setup --include-credentials

# Backup everything BUT keep your settings.json in place
claude-env backup my-setup --keep-config

# Backup everything BUT keep your plugins in place
claude-env backup my-setup --keep-plugins

# Only backup specific layers (comma-separated)
claude-env backup my-setup --only customizations
claude-env backup my-setup --only customizations,config
```

**Other flags:**

```bash
# Overwrite an existing backup with the same name
claude-env backup my-setup --force

# Verbose output (shows every file copied/removed)
claude-env --verbose backup my-setup
```

### `restore <name>`

Restores a backup into `~/.claude/`. Before restoring, it **automatically creates a safety backup** of your current environment (named `pre-restore-<timestamp>`) so you can always undo the restore.

```bash
# Restore — your current state is auto-saved first
claude-env restore my-setup

# Skip the auto-backup (you're sure you don't need the current state)
claude-env restore my-setup --force

# Preview what would be restored
claude-env restore my-setup --dry-run
```

**What restore does:**
1. Creates `pre-restore-2026-04-06T14-30-00` backup of current state (unless `--force`)
2. Reads the backup's `manifest.json` to find which layers were saved
3. Copies those layers back into `~/.claude/`

**What restore does NOT do:**
- It does not delete files in `~/.claude/` that aren't in the backup. If the new framework added files, they'll remain alongside your restored files. This is intentional — it's additive, not destructive.

### `list`

Shows all available backups with their creation date, layers, and size.

```bash
claude-env list
```

```
Name                              Created               Layers                            Size
──────────────────────────────────────────────────────────────────────────────────────────────────
my-setup                          2026-04-06 14:30      customizations,config,plugins      2.1M
pre-restore-2026-04-06T14-45-00   2026-04-06 14:45      customizations,config,plugins      1.8M
minimal-config                    2026-04-01 09:00      config                             12K

3 backup(s) found.
```

### `diff <name>`

Compares a backup against your current `~/.claude/` state. Useful for seeing what changed since you took the backup.

```bash
claude-env diff my-setup
```

```
Layer: customizations
  ✓ rules/               — identical
  ~ skills/              — 3 file(s) differ
  + agents/              — only in backup (missing from current)
  ✓ hooks/               — identical
  ✓ CLAUDE.md            — identical

Layer: config
  ~ settings.json        — modified
  ✓ settings.local.json  — identical

Layer: plugins
  ✓ plugins/installed_plugins.json — identical
  ~ plugins/data/        — 5 file(s) differ

Summary: 5 identical, 3 modified, 1 only in backup, 0 only in current
```

**Symbols:**
- `✓` (green) — identical between backup and current
- `~` (yellow) — file/directory exists in both but content differs
- `+` (red) — exists in backup but missing from current (you lost something)
- `-` (red) — exists in current but not in backup (something new was added)

## Global Flags

These go **before** the subcommand:

```bash
claude-env --dry-run backup my-setup        # Preview mode
claude-env --verbose restore my-setup       # Debug output
claude-env --dir /mnt/usb/backups list      # Custom backup location
claude-env --claude-dir /other/.claude diff my-setup  # Non-default Claude dir
```

| Flag | Description |
|------|-------------|
| `--dir <path>` | Backup storage directory (default: `~/.claude-backups`) |
| `--claude-dir <path>` | Claude config directory (default: `~/.claude`) |
| `--dry-run` | Show what would happen without making changes |
| `--verbose` | Show detailed debug output |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CLAUDE_DIR` | Path to Claude config directory | `~/.claude` |
| `BACKUP_DIR` | Path to backup storage | `~/.claude-backups` |
| `NO_COLOR` | Disable colored output (any value) | unset |

Command-line flags override environment variables.

## Common Workflows

### Testing a new agentic framework

```bash
# 1. Save your current setup
claude-env backup before-experiment

# 2. Install/configure the new framework
# ...

# 3. Don't like it? Restore.
claude-env restore before-experiment

# 4. Like it? Your old setup is still saved if you ever want it.
claude-env list
```

### Switching between project-specific configurations

```bash
# Save config for project A
claude-env backup project-a-config --no-reset

# Save config for project B
claude-env backup project-b-config --no-reset

# Switch to project A setup
claude-env restore project-a-config

# Switch to project B setup
claude-env restore project-b-config
```

### Sharing a known-good configuration

```bash
# Take a snapshot of your working setup
claude-env backup team-baseline --no-reset

# The backup lives at ~/.claude-backups/team-baseline/
# Copy it to a shared location, another machine, etc.
cp -r ~/.claude-backups/team-baseline /shared/drive/

# On another machine:
cp -r /shared/drive/team-baseline ~/.claude-backups/
claude-env restore team-baseline
```

### Keeping MCP servers across environment swaps

By default, MCP configs are kept in place. But if you want to include them:

```bash
# Backup everything including MCP
claude-env backup full-backup --include-mcp

# Restore just customizations (not MCP) from that backup
# (restore uses the layers recorded in the manifest)
claude-env restore full-backup
```

### Auditing what changed

```bash
# Take a baseline snapshot
claude-env backup baseline --no-reset

# Work for a while, install plugins, change settings...

# See what changed
claude-env diff baseline
```

## Backup Storage

Backups are stored in `~/.claude-backups/` by default. Each backup is a directory:

```
~/.claude-backups/
  my-setup/
    manifest.json
    rules/
    skills/
    commands/
    agents/
    hooks/
    CLAUDE.md
    settings.json
    settings.local.json
    plugins/
      installed_plugins.json
      config.json
      local/
      data/
  pre-restore-2026-04-06T14-30-00/
    manifest.json
    ...
```

The structure mirrors `~/.claude/` — only the layers that were backed up are present. Backups are plain files. You can copy, move, zip, rsync, or version-control them.

## FAQ

**Q: Will this break my Claude Code installation?**

No. `claude-env` only touches the files listed in its layer definitions. It never modifies Claude Code's binary, your shell configuration, or anything outside `~/.claude/`. Your credentials and MCP servers are kept by default.

**Q: What if I restore and something goes wrong?**

Every `restore` automatically creates a `pre-restore-*` backup first. You can always `claude-env restore pre-restore-2026-04-06T14-30-00` to undo.

**Q: Can I back up only my rules/skills without touching plugins?**

Yes: `claude-env backup my-rules --only customizations`

**Q: Does it work on macOS/Linux?**

Yes. It's pure Bash with standard Unix tools. No platform-specific dependencies. Requires Bash 4.4+ (macOS ships with 3.2, so you'll need `brew install bash`).

**Q: What about per-project `.claude/` directories?**

`claude-env` targets the global `~/.claude/` directory by default. For per-project configs, use `--claude-dir /path/to/project/.claude`.

## Contributing

```bash
# Run the test suite (37 tests)
npx bats tests/claude-env.bats

# Or if bats is installed globally
bats tests/claude-env.bats
```

Tests use [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System) and create isolated temp directories — they never touch your real `~/.claude/`.

## License

[MIT](LICENSE)
