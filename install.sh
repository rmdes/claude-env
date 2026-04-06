#!/usr/bin/env bash
set -euo pipefail

# claude-env installer
# Usage: curl -fsSL https://raw.githubusercontent.com/ricklamers/claude-env/main/install.sh | bash

REPO="claude-env"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
BRANCH="${BRANCH:-main}"

DOWNLOAD_URL="https://raw.githubusercontent.com/ricklamers/${REPO}/${BRANCH}/claude-env"

main() {
    echo "Installing claude-env to $INSTALL_DIR..."

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Download
    if command -v curl &>/dev/null; then
        curl -fsSL "$DOWNLOAD_URL" -o "$INSTALL_DIR/claude-env"
    elif command -v wget &>/dev/null; then
        wget -qO "$INSTALL_DIR/claude-env" "$DOWNLOAD_URL"
    else
        echo "Error: curl or wget required" >&2
        exit 1
    fi

    # Make executable
    chmod +x "$INSTALL_DIR/claude-env"

    # Verify
    if "$INSTALL_DIR/claude-env" version &>/dev/null; then
        echo "claude-env $("$INSTALL_DIR/claude-env" version) installed to $INSTALL_DIR/claude-env"
    else
        echo "Installation failed" >&2
        exit 1
    fi

    # Check PATH
    if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
        echo ""
        echo "NOTE: $INSTALL_DIR is not in your PATH."
        echo "Add this to your shell profile:"
        echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    fi
}

main "$@"
