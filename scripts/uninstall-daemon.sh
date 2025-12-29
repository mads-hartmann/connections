#!/bin/bash
set -euo pipefail

PLIST_NAME="com.connections.server.plist"
NEWSYSLOG_CONF="connections-server.conf"
BINARY_NAME="connections-server"

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "==> Unloading LaunchAgent..."
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true

echo "==> Removing LaunchAgent plist..."
rm -f "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo "==> Removing binary (requires sudo)..."
sudo rm -f "/usr/local/bin/$BINARY_NAME"

echo "==> Removing newsyslog config (requires sudo)..."
sudo rm -f "/etc/newsyslog.d/$NEWSYSLOG_CONF"

echo ""
echo "✅ Uninstallation complete!"
echo ""
echo "Note: Data and logs were preserved:"
echo "  Database: ~/Library/Application Support/Connections/"
echo "  Logs:     ~/Library/Logs/Connections/"
echo ""
echo "To remove data and logs, run:"
echo "  rm -rf ~/Library/Application\\ Support/Connections"
echo "  rm -rf ~/Library/Logs/Connections"
