#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

PLIST_NAME="com.connections.server.plist"
NEWSYSLOG_CONF="connections-server.conf"
BINARY_NAME="connections-server"

DATA_DIR="$HOME/Library/Application Support/Connections"
LOG_DIR="$HOME/Library/Logs/Connections"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "==> Building connections-server..."
cd "$REPO_ROOT"
dune build

echo "==> Creating directories..."
mkdir -p "$DATA_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$LAUNCH_AGENTS_DIR"

echo "==> Installing binary to /usr/local/bin (requires sudo)..."
sudo cp "_build/default/server/bin/main.exe" "/usr/local/bin/$BINARY_NAME"
sudo chmod +x "/usr/local/bin/$BINARY_NAME"

echo "==> Installing LaunchAgent..."
# Substitute __HOME__ placeholder with actual home directory
sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/$PLIST_NAME" > "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo "==> Installing newsyslog config (requires sudo)..."
sudo mkdir -p /etc/newsyslog.d
sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/connections-server.newsyslog.conf" | sudo tee "/etc/newsyslog.d/$NEWSYSLOG_CONF" > /dev/null

echo "==> Loading LaunchAgent..."
# Unload first if already loaded (ignore errors)
launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo ""
echo "✅ Installation complete!"
echo ""
echo "The server is now running as a background daemon."
echo ""
echo "Useful commands:"
echo "  View logs:     tail -f ~/Library/Logs/Connections/server.log"
echo "  Stop daemon:   launchctl unload ~/Library/LaunchAgents/$PLIST_NAME"
echo "  Start daemon:  launchctl load ~/Library/LaunchAgents/$PLIST_NAME"
echo "  Check status:  launchctl list | grep connections"
echo ""
echo "Database location: $DATA_DIR/connections.db"
echo "Log location:      $LOG_DIR/server.log"
