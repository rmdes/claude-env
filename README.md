# claude-env

Safely backup, restore, and manage your Claude Code configuration.

## Why

Claude Code stores everything under `~/.claude/` -- your custom rules, skills, commands, settings, plugins, MCP servers, and credentials. There is no built-in way to snapshot this environment, swap between configurations, or reset to a clean slate without losing your work.

`claude-env` solves this by treating your Claude Code environment as a set of composable **layers**. Back up the layers you care about, reset the rest, and restore any snapshot later. Switch between project-specific setups, test new frameworks without risk, or share a known-good configuration across machines.

## Quick Start

```bash
# Save current environment
claude-env backup my-setup

# Test a new framework, install plugins, change settings...

# Come back to your setup
claude-env restore my-setup
```

## Installation

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/claude-env/main/install.sh | bash
```

### Manual

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/yourusername/claude-env/main/claude-env -o claude-env

# Make it executable
chmod +x claude-env

# Move to somewhere in your PATH
mv claude-env ~/.local/bin/
```

## Commands

### `backup [name]`

Create a named snapshot of the current Claude environment.

```bash
claude-env backup                       # Auto-generated timestamp name
claude-env backup my-setup              # Custom name
claude-env backup my-setup --no-reset   # Backup without clearing the environment
claude-env backup --include-mcp         # Also backup MCP server configs
claude-env backup --include-credentials # Also backup credentials
claude-env backup --keep-config         # Don't reset config files after backup
claude-env backup --keep-plugins        # Don't reset plugins after backup
claude-env backup --only customizations # Only backup specific layers (comma-separated)
claude-env backup my-setup --force      # Overwrite an existing backup with the same name
```

By default, backup copies the **customizations**, **config**, **plugins**, and **integrations** layers, then removes them from `~/.claude/` (reset). Credentials and MCP configs are kept in place unless you explicitly include them.

### `restore <name>`

Restore a previously saved snapshot.

```bash
claude-env restore my-setup             # Restore (auto-backs up current state first)
claude-env restore my-setup --force     # Restore without auto-backup
```

Before restoring, `claude-env` automatically creates a `pre-restore-<timestamp>` backup of your current environment so you can always go back.

### `list`

List all available snapshots.

```bash
claude-env list
```

Output:

```
Name                              Created               Layers                            Size
──────────────────────────────────────────────────────────────────────────────────────────────────
my-setup                          2026-04-06 12:30      customizations,config,plugins      2.1M
pre-restore-2026-04-06T12-45-00   2026-04-06 12:45      customizations,config,plugins      1.8M

2 backup(s) found.
```

### `diff <name>`

Show differences between the current environment and a snapshot.

```bash
claude-env diff my-setup
```

Output:

```
Layer: customizations
  ~ rules/               — 3 file(s) differ
  + skills/              — only in backup (missing from current)

Layer: config
  ✓ settings.json        — identical

Summary: 1 identical, 1 modified, 1 only in backup, 0 only in current
```

## Layer Reference

| Layer | Contents | Default Behavior |
|-------|----------|------------------|
| **customizations** | `rules/`, `skills/`, `commands/`, `agents/`, `hooks/`, `CLAUDE.md` | Backup + reset |
| **config** | `settings.json`, `settings.local.json`, and other config files | Backup + reset |
| **plugins** | `plugins/installed_plugins.json`, `plugins/config.json`, `plugins/local/`, `plugins/data/` | Backup + reset |
| **integrations** | (reserved for future use) | Backup + reset |
| **credentials** | `.credentials.json` | Keep (opt-in with `--include-credentials`) |
| **mcp** | `mcp-servers/`, `.mcp.json` | Keep (opt-in with `--include-mcp`) |

**Backup + reset** means the layer is copied to the snapshot and then removed from `~/.claude/`.
**Keep** means the layer stays in place and is not included in the snapshot unless you opt in.

## Global Flags

| Flag | Description |
|------|-------------|
| `--dir <path>` | Set backup storage directory (default: `~/.claude-backups`) |
| `--claude-dir <path>` | Set Claude config directory (default: `~/.claude`) |
| `--dry-run` | Show what would be done without making changes |
| `--verbose` | Enable debug output |

Global flags must appear **before** the subcommand:

```bash
claude-env --dry-run backup my-setup
claude-env --claude-dir /path/to/.claude list
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CLAUDE_DIR` | Path to the Claude config directory | `~/.claude` |
| `BACKUP_DIR` | Path to backup storage | `~/.claude-backups` |

Command-line flags (`--claude-dir`, `--dir`) take precedence over environment variables.

## How It Works

`claude-env` organizes the contents of `~/.claude/` into six **layers**, each grouping related files by purpose. When you run `backup`, it:

1. Resolves which layers to backup and which to keep, based on defaults and flags.
2. Copies each layer's files into a named snapshot directory under `~/.claude-backups/<name>/`.
3. Writes a `manifest.json` recording the backup metadata (name, timestamp, layers included).
4. Resets (removes) the backed-up layers from `~/.claude/` unless `--no-reset` is set.

When you run `restore`, it:

1. Creates an automatic pre-restore backup of the current environment (skip with `--force`).
2. Reads the snapshot's `manifest.json` to determine which layers were saved.
3. Copies the snapshot's files back into `~/.claude/`.

## Contributing

Run the test suite:

```bash
bats tests/
```

Tests use [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System). The test suite covers all commands, flag combinations, layer resolution, and edge cases.

## License

[MIT](LICENSE)
