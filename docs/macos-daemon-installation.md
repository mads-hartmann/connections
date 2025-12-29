# macOS Daemon Installation

To run the server as a background daemon on macOS:

```bash
./scripts/install-daemon.sh
```

This will:
- Build the server binary
- Install it to `/usr/local/bin/connections-server`
- Create a LaunchAgent that starts on login
- Configure log rotation via newsyslog

**Locations:**
- Database: `~/Library/Application Support/Connections/connections.db`
- Logs: `~/Library/Logs/Connections/server.log`

**Managing the daemon:**

```bash
# View logs
tail -f ~/Library/Logs/Connections/server.log

# Stop the daemon
launchctl unload ~/Library/LaunchAgents/com.connections.server.plist

# Start the daemon
launchctl load ~/Library/LaunchAgents/com.connections.server.plist

# Check if running
launchctl list | grep connections
```

**Uninstalling:**

```bash
./scripts/uninstall-daemon.sh
```

This preserves your database and logs. To remove them:

```bash
rm -rf ~/Library/Application\ Support/Connections
rm -rf ~/Library/Logs/Connections
```