# CLAUDE.md

## Project Overview

`claude-env` is a single-file Bash CLI tool (~750 lines) that backs up, restores, lists, and diffs Claude Code environments (`~/.claude/`). It organizes the config directory into named **layers** and operates on them independently.

## Architecture

Single script (`claude-env`) with subcommand dispatch. No external dependencies beyond Bash 4.4+ and standard Unix tools.

```
claude-env <global-flags> <subcommand> <subcommand-flags> [name]

Global flags parsed first → subcommand dispatch → subcommand parses its own flags
```

### Layer System

Six layers, each mapping to specific paths in `$CLAUDE_DIR`:

| Layer | Array Variable | Default |
|-------|---------------|---------|
| customizations | `LAYER_CUSTOMIZATIONS` | backup+reset |
| config | `LAYER_CONFIG` | backup+reset |
| plugins | `LAYER_PLUGINS` | backup+reset |
| integrations | `LAYER_INTEGRATIONS` (empty, reserved) | backup+reset |
| credentials | `LAYER_CREDENTIALS` | keep |
| mcp | `LAYER_MCP` | keep |

`resolve_layers()` computes `RESOLVED_BACKUP` and `RESOLVED_KEEP` arrays from defaults + flags.

### Key Functions

- `get_layer_paths <layer>` — prints paths for a layer (handles empty arrays)
- `resolve_layers` — computes backup/keep arrays from flags
- `_json_array` — builds JSON arrays without jq
- `_array_contains` / `_array_remove` — array utilities
- `cmd_backup` — copy phase → manifest → reset phase → summary
- `cmd_restore` — auto-backup → read manifest → restore phase → summary
- `cmd_list` — scan backup dirs → parse manifests → formatted table
- `cmd_diff` — read manifest → compare per layer per path → summary

## Commands

```bash
# Development
./claude-env help                    # Show usage
./claude-env version                 # Show version
./claude-env debug-layers            # Show resolved layers (hidden subcommand)
./claude-env debug-layers --include-mcp  # Test layer resolution with flags

# Testing
npx bats tests/claude-env.bats      # Run all 37 tests

# Testing with isolated dirs (safe, never touches real ~/.claude/)
export CLAUDE_DIR=/tmp/test-claude BACKUP_DIR=/tmp/test-backups
./claude-env backup test --no-reset
./claude-env list
./claude-env diff test
./claude-env restore test
```

## Code Conventions

- `set -euo pipefail` — strict mode everywhere
- Colors auto-detected (tty check + `NO_COLOR` respect)
- No jq dependency — JSON built with printf, parsed with grep/sed
- `local` for all function variables
- Empty array guard: `[[ ${#arr[@]} -eq 0 ]] && return 0`
- Arithmetic with `|| true` to prevent `set -e` exit on `(( 0 ))`
- Manifest parsing: `grep + sed`, not jq (portability)

## Testing

Tests use BATS with isolated temp directories. Every test creates its own `$CLAUDE_DIR` and `$BACKUP_DIR` in a tmpdir, so tests never interfere with each other or with the real system.

```bash
npx bats tests/claude-env.bats           # All tests
npx bats tests/claude-env.bats -f backup  # Filter by name
```

Test helper at `tests/test_helper.bash` creates a realistic fixture with files in every layer.

## File Structure

```
claude-env          # The CLI tool (single file, executable)
install.sh          # One-liner installer
tests/
  test_helper.bash  # Shared setup/teardown for BATS
  claude-env.bats   # 37 test cases
docs/
  plans/            # Design and implementation docs
README.md           # User documentation
LICENSE             # MIT
```

## Common Pitfalls

- **Empty `LAYER_INTEGRATIONS`**: The integrations layer is reserved and empty. `get_layer_paths` handles this with an early return, and the copy/reset loops skip empty paths. Don't remove these guards.
- **`set -e` with arithmetic**: `(( count++ ))` exits when count is 0 because `(( 0 ))` returns exit code 1. Always use `(( count++ )) || true`.
- **Manifest JSON parsing**: Uses simple grep/sed. Works because the manifest is flat (no nested objects). If manifest format changes, parsing needs updating.
- **Auto-backup recursion in restore**: `cmd_restore` calls `cmd_backup` for the auto-backup. Layer flags are reset before the call to prevent flag leakage.
