# CLAUDE.md

## Project Overview

`claude-env` is a single-file Bash CLI that backs up, restores, lists, and diffs Claude Code environments (`~/.claude/`).

## Architecture

**Exclude-based model**: backs up EVERYTHING in `$CLAUDE_DIR`, only skipping items on the exclude list. This means new files/dirs Claude Code creates are automatically covered without script changes.

Default excludes: `.credentials.json`, `mcp-servers/`, `.mcp.json`. Flags `--include-mcp` and `--include-credentials` remove items from the exclude list. `--exclude <path>` adds items.

Single script, subcommand dispatch, no external dependencies beyond Bash 4.4+ and standard Unix tools.

### Key Functions

- `_build_excludes` — computes exclude list from defaults + flags
- `_list_claude_items` — lists all top-level items in CLAUDE_DIR (files and dirs, including dotfiles)
- `_is_excluded` — checks if an item matches any exclude pattern
- `cmd_backup` — enumerate items -> skip excludes -> copy -> write manifest -> reset
- `cmd_restore` — auto-backup current -> copy everything from backup except manifest
- `cmd_list` — scan backup dirs -> parse manifests -> formatted table
- `cmd_diff` — union of backup + current items -> compare each -> summary

### Manifest v2

```json
{
  "version": 2,
  "backed_up": ["list", "of", "actual", "items"],
  "excluded": ["items", "that", "were", "skipped"]
}
```

v1 manifests (with "layers" and "kept") are still readable by `list`.

## Commands

```bash
./claude-env backup my-name              # Backup + reset
./claude-env backup --no-reset snapshot  # Snapshot only
./claude-env restore my-name             # Restore (auto-backup first)
./claude-env list                        # List backups
./claude-env diff my-name                # Compare backup vs current

# Testing
npx bats tests/claude-env.bats          # 38 tests
```

## Code Conventions

- `set -euo pipefail`
- Colors auto-detected (tty + `NO_COLOR`)
- No jq — JSON built with printf, parsed with grep/sed
- `local` for all function variables
- Arithmetic with `|| true` to prevent `set -e` exit on `(( 0 ))`

## Testing

BATS with isolated temp dirs. Every test creates its own `$CLAUDE_DIR` and `$BACKUP_DIR`.

Key tests: #15 ("new unknown files are backed up automatically") and #16 ("hidden dotfiles are backed up") prove the exclude-based model works.

## File Structure

```
claude-env              # The CLI tool
install.sh              # One-liner installer
tests/
  test_helper.bash      # Shared setup/teardown
  claude-env.bats       # 38 tests
README.md
LICENSE
```
