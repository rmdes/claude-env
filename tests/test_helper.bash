#!/usr/bin/env bash
# test_helper.bash — setup/teardown for claude-env BATS tests

# Path to the script under test
CLAUDE_ENV="$BATS_TEST_DIRNAME/../claude-env"

setup() {
    # Create isolated temp directories for each test
    export CLAUDE_DIR="$(mktemp -d)"
    export BACKUP_DIR="$(mktemp -d)"

    # Populate CLAUDE_DIR with realistic fixture covering everything
    # that Claude Code puts in ~/.claude/

    # -- Customizations --
    mkdir -p "$CLAUDE_DIR/rules"
    echo "# Test rule" > "$CLAUDE_DIR/rules/test-rule.md"

    mkdir -p "$CLAUDE_DIR/skills/test-skill"
    echo "# Test skill" > "$CLAUDE_DIR/skills/test-skill/skill.md"

    mkdir -p "$CLAUDE_DIR/commands"
    echo "# Test command" > "$CLAUDE_DIR/commands/test-cmd.md"

    mkdir -p "$CLAUDE_DIR/agents"
    echo "# Test agent" > "$CLAUDE_DIR/agents/test-agent.md"

    mkdir -p "$CLAUDE_DIR/hooks"
    echo "#!/bin/bash" > "$CLAUDE_DIR/hooks/pre-commit.sh"

    echo "# Project CLAUDE.md" > "$CLAUDE_DIR/CLAUDE.md"
    echo "# Agents routing" > "$CLAUDE_DIR/AGENTS.md"

    # -- Config --
    echo '{"theme": "dark"}' > "$CLAUDE_DIR/settings.json"
    echo '{"local": true}' > "$CLAUDE_DIR/settings.local.json"
    echo '#!/bin/bash' > "$CLAUDE_DIR/statusline.sh"
    echo '{"version": "1.0"}' > "$CLAUDE_DIR/.sisyphus-config.json"

    # -- Plugins --
    mkdir -p "$CLAUDE_DIR/plugins/cache/some-plugin"
    mkdir -p "$CLAUDE_DIR/plugins/data"
    mkdir -p "$CLAUDE_DIR/plugins/local"
    mkdir -p "$CLAUDE_DIR/plugins/marketplaces"
    echo '{"plugins": []}' > "$CLAUDE_DIR/plugins/installed_plugins.json"
    echo '{"key": "val"}' > "$CLAUDE_DIR/plugins/config.json"
    echo '{"cached": true}' > "$CLAUDE_DIR/plugins/cache/some-plugin/index.js"

    # -- Runtime/session state --
    mkdir -p "$CLAUDE_DIR/projects/test-project"
    echo '{"session": true}' > "$CLAUDE_DIR/projects/test-project/session.json"
    mkdir -p "$CLAUDE_DIR/sessions"
    echo '{"active": true}' > "$CLAUDE_DIR/sessions/current.json"
    echo '{"history": []}' > "$CLAUDE_DIR/history.jsonl"
    mkdir -p "$CLAUDE_DIR/cache"
    echo '{"c": 1}' > "$CLAUDE_DIR/cache/stuff.json"
    mkdir -p "$CLAUDE_DIR/debug"
    mkdir -p "$CLAUDE_DIR/file-history"
    mkdir -p "$CLAUDE_DIR/shell-snapshots"
    mkdir -p "$CLAUDE_DIR/session-env"
    mkdir -p "$CLAUDE_DIR/paste-cache"
    mkdir -p "$CLAUDE_DIR/telemetry"
    mkdir -p "$CLAUDE_DIR/statsig"
    mkdir -p "$CLAUDE_DIR/ide"
    mkdir -p "$CLAUDE_DIR/plans"
    mkdir -p "$CLAUDE_DIR/tasks"
    mkdir -p "$CLAUDE_DIR/todos"
    mkdir -p "$CLAUDE_DIR/backups"
    echo '{"stats": true}' > "$CLAUDE_DIR/stats-cache.json"
    echo '{"warned": true}' > "$CLAUDE_DIR/security_warnings_state_abc123.json"
    echo '{"warned": false}' > "$CLAUDE_DIR/security_warnings_state_def456.json"

    # -- Credentials --
    echo '{"token": "secret123"}' > "$CLAUDE_DIR/.credentials.json"

    # -- MCP --
    mkdir -p "$CLAUDE_DIR/mcp-servers"
    echo '{"server": "test"}' > "$CLAUDE_DIR/mcp-servers/test.json"
    echo '{"mcpServers": {}}' > "$CLAUDE_DIR/.mcp.json"
}

teardown() {
    rm -rf "$CLAUDE_DIR" "$BACKUP_DIR"
}
