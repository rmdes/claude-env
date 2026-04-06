#!/usr/bin/env bats

load test_helper

# =============================================================================
# BACKUP — basic behavior
# =============================================================================

@test "backup: creates directory with manifest" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup my-test
    [ "$status" -eq 0 ]
    [ -d "$BACKUP_DIR/my-test" ]
    [ -f "$BACKUP_DIR/my-test/manifest.json" ]
}

@test "backup: manifest is valid JSON with required fields" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup json-test
    [ "$status" -eq 0 ]
    manifest="$BACKUP_DIR/json-test/manifest.json"
    # Check required fields exist
    grep -q '"version"' "$manifest"
    grep -q '"created"' "$manifest"
    grep -q '"name"' "$manifest"
    grep -q '"layers"' "$manifest"
    grep -q '"kept"' "$manifest"
    grep -q '"claude_dir"' "$manifest"
}

@test "backup: default excludes credentials" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup cred-test
    [ "$status" -eq 0 ]
    [ ! -f "$BACKUP_DIR/cred-test/.credentials.json" ]
}

@test "backup: default excludes mcp" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup mcp-test
    [ "$status" -eq 0 ]
    [ ! -d "$BACKUP_DIR/mcp-test/mcp-servers" ]
    [ ! -f "$BACKUP_DIR/mcp-test/.mcp.json" ]
}

@test "backup: --include-mcp includes MCP files" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --include-mcp mcp-inc
    [ "$status" -eq 0 ]
    [ -d "$BACKUP_DIR/mcp-inc/mcp-servers" ]
    [ -f "$BACKUP_DIR/mcp-inc/.mcp.json" ]
}

@test "backup: --include-credentials includes credential files" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --include-credentials cred-inc
    [ "$status" -eq 0 ]
    [ -f "$BACKUP_DIR/cred-inc/.credentials.json" ]
}

@test "backup: --no-reset keeps source files intact" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset noreset-test
    [ "$status" -eq 0 ]
    # Source files should still exist
    [ -d "$CLAUDE_DIR/rules" ]
    [ -f "$CLAUDE_DIR/CLAUDE.md" ]
    [ -f "$CLAUDE_DIR/settings.json" ]
}

@test "backup: default reset removes backed-up layers" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup reset-test
    [ "$status" -eq 0 ]
    # Customizations should be removed
    [ ! -d "$CLAUDE_DIR/rules" ]
    [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]
    # Config should be removed
    [ ! -f "$CLAUDE_DIR/settings.json" ]
}

@test "backup: keeps credentials after reset" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup keep-cred
    [ "$status" -eq 0 ]
    # Credentials should remain (in keep layer by default)
    [ -f "$CLAUDE_DIR/.credentials.json" ]
}

@test "backup: keeps mcp after reset" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup keep-mcp
    [ "$status" -eq 0 ]
    # MCP should remain (in keep layer by default)
    [ -d "$CLAUDE_DIR/mcp-servers" ]
    [ -f "$CLAUDE_DIR/.mcp.json" ]
}

@test "backup: --keep-config preserves settings.json" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --keep-config keepcfg
    [ "$status" -eq 0 ]
    # settings.json should still exist (config layer kept)
    [ -f "$CLAUDE_DIR/settings.json" ]
    # But customizations should be removed (still backed up)
    [ ! -d "$CLAUDE_DIR/rules" ]
}

@test "backup: --keep-plugins preserves plugins" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --keep-plugins keepplug
    [ "$status" -eq 0 ]
    # Plugins should still exist
    [ -d "$CLAUDE_DIR/plugins" ]
    # But customizations should be removed
    [ ! -d "$CLAUDE_DIR/rules" ]
}

@test "backup: --only limits scope to specified layers" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --only customizations only-test
    [ "$status" -eq 0 ]
    # Only customizations backed up
    [ -d "$BACKUP_DIR/only-test/rules" ]
    [ -f "$BACKUP_DIR/only-test/CLAUDE.md" ]
    # Config should NOT be backed up
    [ ! -f "$BACKUP_DIR/only-test/settings.json" ]
    # Config should still exist in source (it's in keep now)
    [ -f "$CLAUDE_DIR/settings.json" ]
}

@test "backup: --dry-run creates nothing on disk" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" --dry-run backup dryrun-test
    [ "$status" -eq 0 ]
    [ ! -d "$BACKUP_DIR/dryrun-test" ]
    # Source should be untouched
    [ -d "$CLAUDE_DIR/rules" ]
}

@test "backup: duplicate name errors without --force" {
    # Create first backup
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset dupe-test
    [ "$status" -eq 0 ]
    # Try again — should fail
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset dupe-test
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "backup: --force overwrites existing backup" {
    # Create first backup
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset force-test
    [ "$status" -eq 0 ]
    # Overwrite with --force
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset --force force-test
    [ "$status" -eq 0 ]
    [ -f "$BACKUP_DIR/force-test/manifest.json" ]
}

@test "backup: auto-generates timestamp name when none given" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup
    [ "$status" -eq 0 ]
    # Should have created a directory with timestamp-like name (YYYY-MM-DDTHH-MM-SS)
    local count
    count=$(ls -1 "$BACKUP_DIR" | wc -l)
    [ "$count" -eq 1 ]
    local name
    name=$(ls -1 "$BACKUP_DIR")
    [[ "$name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]
}

# =============================================================================
# RESTORE
# =============================================================================

@test "restore: copies files back to CLAUDE_DIR" {
    # Backup then reset
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup restore-src
    [ "$status" -eq 0 ]
    [ ! -d "$CLAUDE_DIR/rules" ]

    # Restore (--force to skip auto-backup)
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" restore --force restore-src
    [ "$status" -eq 0 ]
    [ -d "$CLAUDE_DIR/rules" ]
    [ -f "$CLAUDE_DIR/rules/test-rule.md" ]
    [ -f "$CLAUDE_DIR/CLAUDE.md" ]
}

@test "restore: auto-creates pre-restore backup" {
    # Create a backup to restore from
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset auto-bak-src
    [ "$status" -eq 0 ]

    # Restore without --force — should auto-backup first
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" restore auto-bak-src
    [ "$status" -eq 0 ]
    # Should have a pre-restore-* backup
    local pre_restore
    pre_restore=$(ls -1 "$BACKUP_DIR" | grep "^pre-restore-")
    [ -n "$pre_restore" ]
}

@test "restore: --force skips auto-backup" {
    # Create a backup
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset force-restore-src
    [ "$status" -eq 0 ]

    # Restore with --force
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" restore --force force-restore-src
    [ "$status" -eq 0 ]
    # No pre-restore backups
    local pre_count
    pre_count=$(ls -1 "$BACKUP_DIR" | grep -c "^pre-restore-" || true)
    [ "$pre_count" -eq 0 ]
}

@test "restore: nonexistent backup errors" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" restore does-not-exist
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "restore: missing name errors" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" restore
    [ "$status" -ne 0 ]
    [[ "$output" == *"name required"* || "$output" == *"Backup name required"* ]]
}

@test "restore: --dry-run modifies nothing" {
    # Create backup (with reset)
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup dry-restore-src
    [ "$status" -eq 0 ]
    [ ! -d "$CLAUDE_DIR/rules" ]

    # Dry-run restore
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" --dry-run restore --force dry-restore-src
    [ "$status" -eq 0 ]
    # Files should NOT be restored
    [ ! -d "$CLAUDE_DIR/rules" ]
}

# =============================================================================
# LIST
# =============================================================================

@test "list: shows existing backups" {
    # Create some backups
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset list-a
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset list-b

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"list-a"* ]]
    [[ "$output" == *"list-b"* ]]
}

@test "list: empty shows 'No backups found'" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"No backups found"* ]]
}

@test "list: shows count" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset count-a
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset count-b
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset count-c

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 backup(s) found"* ]]
}

# =============================================================================
# DIFF
# =============================================================================

@test "diff: identical shows 'identical'" {
    # Backup without reset so source matches backup
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset diff-ident

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" diff diff-ident
    [ "$status" -eq 0 ]
    [[ "$output" == *"identical"* ]]
}

@test "diff: detects modified files" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset diff-mod

    # Modify a file in the current env
    echo "# Modified rule" > "$CLAUDE_DIR/rules/test-rule.md"

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" diff diff-mod
    [ "$status" -eq 0 ]
    [[ "$output" == *"modified"* || "$output" == *"differ"* ]]
}

@test "diff: detects backup-only files" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset diff-only

    # Remove a file from current env
    rm -rf "$CLAUDE_DIR/rules"

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" diff diff-only
    [ "$status" -eq 0 ]
    [[ "$output" == *"only in backup"* ]]
}

@test "diff: nonexistent backup errors" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" diff ghost
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

# =============================================================================
# GLOBAL FLAGS
# =============================================================================

@test "global: --dir override works" {
    local custom_dir
    custom_dir="$(mktemp -d)"

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$custom_dir" backup --no-reset dir-test
    [ "$status" -eq 0 ]
    [ -d "$custom_dir/dir-test" ]

    rm -rf "$custom_dir"
}

@test "global: --claude-dir override works" {
    local alt_claude
    alt_claude="$(mktemp -d)"
    mkdir -p "$alt_claude/rules"
    echo "# Alt rule" > "$alt_claude/rules/alt.md"

    run "$CLAUDE_ENV" --claude-dir "$alt_claude" --dir "$BACKUP_DIR" backup --no-reset claude-dir-test
    [ "$status" -eq 0 ]
    [ -f "$BACKUP_DIR/claude-dir-test/rules/alt.md" ]

    rm -rf "$alt_claude"
}

@test "global: help shows usage" {
    run "$CLAUDE_ENV" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE"* ]]
    [[ "$output" == *"COMMANDS"* ]]
}

@test "global: --help shows usage" {
    run "$CLAUDE_ENV" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE"* ]]
}

@test "global: version shows version" {
    run "$CLAUDE_ENV" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-env"* ]]
    [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "global: --version shows version" {
    run "$CLAUDE_ENV" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"claude-env"* ]]
}

@test "global: unknown command errors" {
    run "$CLAUDE_ENV" frobnicate
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown command"* ]]
}
