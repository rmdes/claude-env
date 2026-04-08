#!/usr/bin/env bats

load test_helper

# =============================================================================
# BACKUP — core behavior
# =============================================================================

@test "backup: creates directory with manifest" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup my-test
    [ "$status" -eq 0 ]
    [ -d "$BACKUP_DIR/my-test" ]
    [ -f "$BACKUP_DIR/my-test/manifest.json" ]
}

@test "backup: manifest is v2 JSON with backed_up and excluded" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup json-test
    [ "$status" -eq 0 ]
    manifest="$BACKUP_DIR/json-test/manifest.json"
    grep -q '"version": 2' "$manifest"
    grep -q '"backed_up"' "$manifest"
    grep -q '"excluded"' "$manifest"
    grep -q '"name": "json-test"' "$manifest"
}

@test "backup: backs up EVERYTHING except credentials and mcp by default" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset full-test
    [ "$status" -eq 0 ]

    # All of these should be in the backup
    [ -d "$BACKUP_DIR/full-test/rules" ]
    [ -d "$BACKUP_DIR/full-test/skills" ]
    [ -d "$BACKUP_DIR/full-test/agents" ]
    [ -d "$BACKUP_DIR/full-test/plugins" ]
    [ -d "$BACKUP_DIR/full-test/projects" ]
    [ -d "$BACKUP_DIR/full-test/sessions" ]
    [ -d "$BACKUP_DIR/full-test/cache" ]
    [ -f "$BACKUP_DIR/full-test/CLAUDE.md" ]
    [ -f "$BACKUP_DIR/full-test/AGENTS.md" ]
    [ -f "$BACKUP_DIR/full-test/settings.json" ]
    [ -f "$BACKUP_DIR/full-test/history.jsonl" ]
    [ -f "$BACKUP_DIR/full-test/stats-cache.json" ]
    [ -f "$BACKUP_DIR/full-test/security_warnings_state_abc123.json" ]
    [ -d "$BACKUP_DIR/full-test/plugins/cache" ]

    # Credentials and MCP should NOT be in the backup
    [ ! -f "$BACKUP_DIR/full-test/.credentials.json" ]
    [ ! -d "$BACKUP_DIR/full-test/mcp-servers" ]
    [ ! -f "$BACKUP_DIR/full-test/.mcp.json" ]
}

@test "backup: default reset removes backed-up items" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup reset-test
    [ "$status" -eq 0 ]

    # Backed-up items should be removed
    [ ! -d "$CLAUDE_DIR/rules" ]
    [ ! -d "$CLAUDE_DIR/skills" ]
    [ ! -d "$CLAUDE_DIR/plugins" ]
    [ ! -d "$CLAUDE_DIR/projects" ]
    [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]
    [ ! -f "$CLAUDE_DIR/settings.json" ]
    [ ! -f "$CLAUDE_DIR/history.jsonl" ]
}

@test "backup: credentials kept after reset" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup cred-keep
    [ "$status" -eq 0 ]
    [ -f "$CLAUDE_DIR/.credentials.json" ]
}

@test "backup: mcp kept after reset" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup mcp-keep
    [ "$status" -eq 0 ]
    [ -d "$CLAUDE_DIR/mcp-servers" ]
    [ -f "$CLAUDE_DIR/.mcp.json" ]
}

@test "backup: --include-mcp includes MCP in backup and resets it" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --include-mcp mcp-inc
    [ "$status" -eq 0 ]
    [ -d "$BACKUP_DIR/mcp-inc/mcp-servers" ]
    [ -f "$BACKUP_DIR/mcp-inc/.mcp.json" ]
    # MCP should be removed from current
    [ ! -d "$CLAUDE_DIR/mcp-servers" ]
    [ ! -f "$CLAUDE_DIR/.mcp.json" ]
}

@test "backup: --include-credentials includes credentials in backup" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --include-credentials cred-inc
    [ "$status" -eq 0 ]
    [ -f "$BACKUP_DIR/cred-inc/.credentials.json" ]
    [ ! -f "$CLAUDE_DIR/.credentials.json" ]
}

@test "backup: --no-reset keeps source files intact" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset noreset
    [ "$status" -eq 0 ]
    # Everything should still exist
    [ -d "$CLAUDE_DIR/rules" ]
    [ -d "$CLAUDE_DIR/skills" ]
    [ -f "$CLAUDE_DIR/CLAUDE.md" ]
    [ -d "$CLAUDE_DIR/projects" ]
}

@test "backup: --exclude skips additional paths" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset --exclude plugins --exclude projects excl-test
    [ "$status" -eq 0 ]
    # Excluded items should not be in backup
    [ ! -d "$BACKUP_DIR/excl-test/plugins" ]
    [ ! -d "$BACKUP_DIR/excl-test/projects" ]
    # Other items should be
    [ -d "$BACKUP_DIR/excl-test/rules" ]
    [ -f "$BACKUP_DIR/excl-test/settings.json" ]
}

@test "backup: --dry-run creates nothing on disk" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" --dry-run backup dryrun
    [ "$status" -eq 0 ]
    [ ! -d "$BACKUP_DIR/dryrun" ]
    [[ "$output" == *"dry-run"* ]]
}

@test "backup: duplicate name errors without --force" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset dup
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup dup
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "backup: --force overwrites existing backup" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset forceme
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset --force forceme
    [ "$status" -eq 0 ]
}

@test "backup: auto-generates timestamp name when none given" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset
    [ "$status" -eq 0 ]
    # Should have created a directory with timestamp-like name
    local count
    count=$(find "$BACKUP_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l)
    [ "$count" -eq 1 ]
}

# =============================================================================
# BACKUP — catches everything
# =============================================================================

@test "backup: new unknown files in CLAUDE_DIR are backed up automatically" {
    # Simulate Claude Code adding a new file/dir we don't know about
    echo '{"future": true}' > "$CLAUDE_DIR/some-future-feature.json"
    mkdir -p "$CLAUDE_DIR/new-component"
    echo "data" > "$CLAUDE_DIR/new-component/stuff.txt"

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset future-test
    [ "$status" -eq 0 ]

    # These should be backed up even though the script doesn't "know" about them
    [ -f "$BACKUP_DIR/future-test/some-future-feature.json" ]
    [ -d "$BACKUP_DIR/future-test/new-component" ]
    [ -f "$BACKUP_DIR/future-test/new-component/stuff.txt" ]
}

@test "backup: hidden dotfiles in CLAUDE_DIR are backed up" {
    echo '{"hidden": true}' > "$CLAUDE_DIR/.some-hidden-config.json"

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset dotfile-test
    [ "$status" -eq 0 ]
    [ -f "$BACKUP_DIR/dotfile-test/.some-hidden-config.json" ]
}

# =============================================================================
# RESTORE
# =============================================================================

@test "restore: copies files back to CLAUDE_DIR" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset res-test

    # Delete something
    rm -rf "$CLAUDE_DIR/rules"

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" restore --force res-test
    [ "$status" -eq 0 ]
    [ -d "$CLAUDE_DIR/rules" ]
    [ -f "$CLAUDE_DIR/rules/test-rule.md" ]
}

@test "restore: restores everything from backup, not just known paths" {
    # Add unknown file, backup, reset, restore
    echo "surprise" > "$CLAUDE_DIR/surprise-file.txt"
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup res-unknown

    # After reset, surprise file is gone
    [ ! -f "$CLAUDE_DIR/surprise-file.txt" ]

    # Restore brings it back
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" restore --force res-unknown
    [ "$status" -eq 0 ]
    [ -f "$CLAUDE_DIR/surprise-file.txt" ]
}

@test "restore: auto-creates pre-restore backup" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset auto-bak

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" restore auto-bak
    [ "$status" -eq 0 ]

    # Should have created a pre-restore-* backup
    local pre_restore
    pre_restore=$(find "$BACKUP_DIR" -maxdepth 1 -name "pre-restore-*" -type d | head -1)
    [ -n "$pre_restore" ]
    [ -f "$pre_restore/manifest.json" ]
}

@test "restore: --force skips auto-backup" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset force-res

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" restore --force force-res
    [ "$status" -eq 0 ]

    local count
    count=$(find "$BACKUP_DIR" -maxdepth 1 -name "pre-restore-*" -type d | wc -l)
    [ "$count" -eq 0 ]
}

@test "restore: nonexistent backup errors" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" restore ghost
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}

@test "restore: missing name errors" {
    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" restore
    [ "$status" -ne 0 ]
}

@test "restore: --dry-run modifies nothing" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset dry-res

    rm -rf "$CLAUDE_DIR/rules"

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" --dry-run restore dry-res
    [ "$status" -eq 0 ]
    # Rules should NOT be restored (dry run)
    [ ! -d "$CLAUDE_DIR/rules" ]
}

# =============================================================================
# LIST
# =============================================================================

@test "list: shows existing backups" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset list-a
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset list-b

    run "$CLAUDE_ENV" --dir "$BACKUP_DIR" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"list-a"* ]]
    [[ "$output" == *"list-b"* ]]
}

@test "list: empty shows 'No backups found'" {
    run "$CLAUDE_ENV" --dir "$BACKUP_DIR" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"No backups found"* ]]
}

@test "list: shows count" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset cnt-test

    run "$CLAUDE_ENV" --dir "$BACKUP_DIR" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 backup(s) found"* ]]
}

# =============================================================================
# DIFF
# =============================================================================

@test "diff: identical shows 'identical'" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset diff-ident

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" diff diff-ident
    [ "$status" -eq 0 ]
    [[ "$output" == *"identical"* ]]
}

@test "diff: detects modified files" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset diff-mod

    echo "# Modified rule" > "$CLAUDE_DIR/rules/test-rule.md"

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" diff diff-mod
    [ "$status" -eq 0 ]
    [[ "$output" == *"modified"* || "$output" == *"differ"* ]]
}

@test "diff: detects backup-only files" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset diff-only

    rm -rf "$CLAUDE_DIR/rules"

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" diff diff-only
    [ "$status" -eq 0 ]
    [[ "$output" == *"only in backup"* ]]
}

@test "diff: detects current-only files" {
    "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" backup --no-reset diff-cur

    echo "new" > "$CLAUDE_DIR/brand-new-file.txt"

    run "$CLAUDE_ENV" --claude-dir "$CLAUDE_DIR" --dir "$BACKUP_DIR" diff diff-cur
    [ "$status" -eq 0 ]
    [[ "$output" == *"only in current"* ]]
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
