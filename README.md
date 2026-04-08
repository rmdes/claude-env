# claude-env

**Safely backup, swap, and restore your entire Claude Code environment.**

Claude Code stores everything under `~/.claude/` — your rules, skills, agents, commands, hooks, plugins (including their full runtime cache), settings, MCP servers, and credentials. It's the accumulated result of weeks or months of customization. There's no built-in way to snapshot it, swap to a clean slate, or roll back.

`claude-env` fixes that. It treats your Claude Code config as a set of **layers** (customizations, config, plugins, runtime, credentials, MCP) and lets you back up, reset, restore, and compare them independently.

## The Problem

You want to try a new agentic framework that integrates with Claude Code. Or you want to start fresh with a minimal setup. Or you need different configurations for different projects. But `~/.claude/` is a mix of:

- **Your work** — rules you wrote, skills you installed, agents you configured, settings you tuned
- **Plugin runtime** — the entire plugin ecosystem including downloaded skills, cached marketplaces, and plugin data (~1GB)
- **Runtime noise** — session logs, caches, telemetry, debug output, temp files

Deleting `~/.claude/` is a nuclear option. Manually copying files is error-prone. You need to know which files matter and which are disposable.

`claude-env` knows the difference. It backs up what matters, ignores what doesn't, and gives you a clean swap.

## Quick Start

```bash
# Save your current environment (typically ~1GB with plugins)
claude-env backup my-setup

# Your ~/.claude/ is now clean — only credentials, MCP configs, and
# regenerable runtime state remain. Claude Code will feel like a fresh install.

# Don't like the new setup? Come back in one command:
claude-env restore my-setup
```

That's it. Your rules, skills, agents, commands, hooks, plugins (with all their cached code), and settings are all back exactly as they were.

### True full reset (first-install experience)

By default, runtime state (sessions, caches, history) is kept since it regenerates automatically. For a complete wipe:

```bash
# Nuclear option: backup + reset EVERYTHING except credentials and MCP (~2GB)
claude-env backup my-setup --include-runtime
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

Make sure `~/.local/bin` is in your `PATH`.

### Requirements

- Bash 4.4+
- Standard Unix tools (cp, rm, diff, du, date, grep, sed)
- No other dependencies. No Python, no Node, no jq.

## How It Works

### Layers

`claude-env` organizes `~/.claude/` into six layers:

| Layer | What's in it | Default behavior | Typical size |
|-------|-------------|-----------------|-------------|
| **customizations** | `rules/`, `skills/`, `commands/`, `agents/`, `hooks/`, `CLAUDE.md` | Backup + reset | ~1MB |
| **config** | `settings.json`, `settings.local.json`, `statusline.sh`, Sisyphus/Pilot config files | Backup + reset | ~50KB |
| **plugins** | The entire `plugins/` directory: registry files, `local/`, `data/`, `cache/` (all downloaded plugin code), `marketplaces/`, `known_marketplaces.json` | Backup + reset | **~1GB** |
| **runtime** | `cache/`, `projects/`, `sessions/`, `todos/`, `tasks/`, `debug/`, `file-history/`, `shell-snapshots/`, `telemetry/`, `history.jsonl`, and other ephemeral state | **Keep** (opt-in with `--include-runtime`) | ~900MB |
| **credentials** | `.credentials.json` | **Keep** (opt-in with `--include-credentials`) | ~7KB |
| **mcp** | `mcp-servers/`, `.mcp.json` | **Keep** (opt-in with `--include-mcp`) | varies |

**"Backup + reset"** means: the files are copied to the backup, then removed from `~/.claude/`. You get a clean slate for that layer.

**"Keep"** means: the files stay in `~/.claude/` and are NOT included in the backup unless you opt in.

#### Why plugins is the biggest layer

The `plugins/` directory isn't just a few JSON config files. It contains:

- `plugins/cache/` — **~650MB** of downloaded plugin source code (superpowers, workflows, skills, LSP servers)
- `plugins/marketplaces/` — **~340MB** of marketplace indexes
- `plugins/data/` — plugin-specific persistent state (e.g., episodic memory databases)
- `plugins/local/` — locally developed plugins
- Registry files — `installed_plugins.json`, `config.json`, `known_marketplaces.json`

If you don't back up `plugins/`, you're not really resetting Claude Code. The old plugin code stays cached and Claude boots up looking exactly the same.

#### Why runtime is kept by default

The runtime layer contains caches, session logs, and debug output that regenerate automatically. Keeping it means faster Claude startup (no re-caching). Including it with `--include-runtime` gives you a true first-install experience but the backup will be ~2GB.

### Manifests

Every backup writes a `manifest.json` that records what was backed up:

```json
{
  "version": 1,
  "created": "2026-04-06T14:30:00Z",
  "name": "my-setup",
  "layers": ["customizations", "config", "plugins"],
  "kept": ["credentials", "mcp", "runtime"],
  "claude_dir": "/home/you/.claude"
}
```

This manifest is how `restore`, `list`, and `diff` know what layers a backup contains.

## Commands

### `backup [name]`

Creates a snapshot of your Claude Code environment. By default, it backs up the customizations, config, and plugins layers, then **resets** them (removes them from `~/.claude/`). Credentials, MCP, and runtime are kept in place.

```bash
# Backup with a name you'll remember (~1GB)
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
# True full reset — also backup+reset all runtime state (~2GB)
claude-env backup my-setup --include-runtime

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
my-setup                          2026-04-06 14:30      customizations,config,plugins      990M
pre-restore-2026-04-06T14-45-00   2026-04-06 14:45      customizations,config,plugins      985M
minimal-config                    2026-04-01 09:00      config                             52K

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
  ~ plugins/             — 12 file(s) differ

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

### True clean-room testing

```bash
# Full reset — first-install experience (credentials + MCP kept)
claude-env backup before-experiment --include-runtime

# Now ~/.claude/ has ONLY credentials and MCP. Claude Code is truly fresh.
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
  my-setup/                         # ~990MB typically
    manifest.json
    rules/
    skills/
    commands/
    agents/
    hooks/
    CLAUDE.md
    settings.json
    settings.local.json
    plugins/                        # The big one
      installed_plugins.json
      config.json
      known_marketplaces.json
      local/                        # Your custom plugins
      data/                         # Plugin state (episodic memory, etc.)
      cache/                        # All downloaded plugin code (~650MB)
      marketplaces/                 # Marketplace indexes (~340MB)
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

**Q: Why is the backup ~1GB?**

Because it includes the full `plugins/` directory. Claude Code downloads plugin source code into `plugins/cache/` (~650MB) and marketplace indexes into `plugins/marketplaces/` (~340MB). Without these, a "reset" leaves the old plugin runtime in place and Claude boots up looking the same.

**Q: Can I make a lighter backup without plugins?**

Yes: `claude-env backup my-rules --only customizations,config` — this skips plugins and produces a ~1MB backup. But your reset won't feel like a fresh install.

**Q: What's the difference between default and `--include-runtime`?**

Default backup (~1GB) resets your customizations, settings, and plugins. Claude Code starts fresh but retains session history, caches, and project data. With `--include-runtime` (~2GB), ALL ephemeral state is also wiped — true first-install experience.

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
