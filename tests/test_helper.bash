#!/usr/bin/env bash
# test_helper.bash — setup/teardown for claude-env BATS tests

# Path to the script under test
CLAUDE_ENV="$BATS_TEST_DIRNAME/../claude-env"

setup() {
    # Create isolated temp directories for each test
    export CLAUDE_DIR="$(mktemp -d)"
    export BACKUP_DIR="$(mktemp -d)"

    # Populate CLAUDE_DIR with test fixtures
    # -- Customizations layer --
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

    # -- Config layer --
    echo '{"theme": "dark"}' > "$CLAUDE_DIR/settings.json"
    echo '#!/bin/bash' > "$CLAUDE_DIR/statusline.sh"
    echo '{"version": "1.0"}' > "$CLAUDE_DIR/.sisyphus-config.json"

    # -- Plugins layer --
    mkdir -p "$CLAUDE_DIR/plugins/local"
    mkdir -p "$CLAUDE_DIR/plugins/data"
    echo '{"plugins": []}' > "$CLAUDE_DIR/plugins/installed_plugins.json"
    echo '{"key": "val"}' > "$CLAUDE_DIR/plugins/config.json"
    echo '[]' > "$CLAUDE_DIR/plugins/known_marketplaces.json"

    # -- Runtime layer --
    mkdir -p "$CLAUDE_DIR/projects/test-project"
    echo '{"session": true}' > "$CLAUDE_DIR/projects/test-project/session.json"
    mkdir -p "$CLAUDE_DIR/sessions"
    echo '{"active": true}' > "$CLAUDE_DIR/sessions/current.json"
    echo '{"history": []}' > "$CLAUDE_DIR/history.jsonl"
    echo '{"warned": true}' > "$CLAUDE_DIR/security_warnings_state_abc123.json"
    echo '{"warned": false}' > "$CLAUDE_DIR/security_warnings_state_def456.json"

    # -- Credentials layer --
    echo '{"token": "secret123"}' > "$CLAUDE_DIR/.credentials.json"

    # -- MCP layer --
    mkdir -p "$CLAUDE_DIR/mcp-servers"
    echo '{"server": "test"}' > "$CLAUDE_DIR/mcp-servers/test.json"
    echo '{"mcpServers": {}}' > "$CLAUDE_DIR/.mcp.json"
}

teardown() {
    # Clean up temp directories
    rm -rf "$CLAUDE_DIR" "$BACKUP_DIR"
}
