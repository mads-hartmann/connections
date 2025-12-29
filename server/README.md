# Connections API Server

API backed by SQlite.

It's written in OCaml (>= 5.4.0) and takes advantage of the new effects system which has influenced the library selection.

| Library | Purpose |
|---------|---------|
| [tapak](https://github.com/syaiful6/tapak) | Web framework built on Piaf with effect-based routing |
| [piaf](https://github.com/anmonteiro/piaf) | HTTP client/server using effects |
| [caqti](https://github.com/paurkedal/ocaml-caqti) | Database abstraction layer |
| [caqti-driver-sqlite3](https://github.com/paurkedal/ocaml-caqti) | SQLite driver for Caqti |
| [caqti-eio](https://github.com/paurkedal/ocaml-caqti) | Eio integration for Caqti |
| [eio](https://github.com/ocaml-multicore/eio) | Effect-based I/O for OCaml 5 |
| [yojson](https://github.com/ocaml-community/yojson) | JSON parsing and serialization |
| [ppx_yojson_conv](https://github.com/janestreet/ppx_yojson_conv) | PPX for deriving JSON converters |
| [syndic](https://github.com/Cumulus/Syndic) | RSS/Atom feed parsing |
| [lambdasoup](https://github.com/aantron/lambdasoup) | HTML parsing for metadata extraction |
| [cmdliner](https://github.com/dbuenzli/cmdliner) | Command-line argument parsing |
| [logs](https://github.com/dbuenzli/logs) | Logging infrastructure |
| [alcotest](https://github.com/mirage/alcotest) | Testing framework |

## Configuration

| Option | Env Variable | Default | Description |
|--------|--------------|---------|-------------|
| `-p`, `--port` | `PORT` | `8080` | Port to listen on |
| `--db` | `DB_PATH` | `connections.db` | Path to SQLite database file |
| `--no-scheduler` | - | `false` | Disable background RSS feed scheduler |
| `--log-file` | - | stderr | Path to log file (if not set, logs to stderr) |

## macOS Daemon Installation

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

## Development

Requires OCaml version 5.4.0

```bash
opam switch create connections 5.4.0
```

Install dependencies using opam. Note that [tapak](https://github.com/syaiful6/tapak) is not published to opam and must be pinned first:

```bash
opam pin add tapak https://github.com/syaiful6/tapak.git -y
opam install . --deps-only
```

- Building: `dune build`
- Formatting: `dune fmt`
- Tests: `dune test`
- Updating snapshots `dune exec server/bin/update_snapshots.exe`

## Tests

Run all tests with `dune test`. The test suite includes:

- **Unit tests** - JSON serialization, URL validation, feed parsing
- **Database tests** - CRUD operations for persons, feeds, articles using in-memory SQLite
- **E2E tests** - Start the server with `server/test/data/test.db` and compare API responses against JSON snapshots in `server/test/data/snapshots/`

To update E2E snapshots after intentional API changes:

```bash
dune exec server/bin/update_snapshots.exe
```