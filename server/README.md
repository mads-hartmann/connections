# Connections API Server

API backed by SQlite.

It's written in OCaml (>= 5.4.0) and takes advantage of the new effects system which has influenced the library selection.

## Project Structure

```
server/
├── bin/                    # Executables
│   └── main.ml             # Server entry point
├── lib/                    # Library code
│   ├── cron/               # Scheduled background jobs
│   │   ├── feed_sync.ml    # RSS feed synchronization (hourly)
│   │   └── article_metadata_sync.ml  # Article metadata fetching (5 min)
│   ├── db/                 # Database queries (Caqti)
│   ├── handlers/           # HTTP request handlers
│   ├── metadata/           # URL metadata extraction
│   │   ├── article.ml      # Article/content metadata (OG, Twitter, JSON-LD)
│   │   ├── contact.ml      # Contact/person metadata (h-card, rel-me, feeds)
│   │   └── extractors/     # Individual metadata extractors
│   │       ├── opengraph.ml
│   │       ├── twitter.ml
│   │       ├── json_ld.ml
│   │       ├── microformats.ml
│   │       └── html_meta.ml
│   ├── model/              # Domain types with JSON serialization
│   ├── opml/               # OPML parsing and import
│   ├── service/            # Business logic layer
│   ├── feed_parser.ml      # RSS/Atom feed parsing utilities
│   ├── html_helpers.ml     # HTML parsing utilities
│   ├── http_client.ml      # HTTP client with redirect handling
│   └── router.ml           # Route definitions
└── test/                   # Test suite
```

### Directory Conventions

- **cron/**: Background jobs that run on a schedule. Each module has `start`/`stop` functions.
- **db/**: Database access layer. One module per table with query functions.
- **handlers/**: HTTP handlers. One module per resource (persons, feeds, articles).
- **metadata/**: URL metadata extraction. `article.ml` and `contact.ml` are the public API; `extractors/` contains format-specific parsers.
- **model/**: Domain types. Each module defines a type `t` with `to_json`, `pp`, and `equal`.
- **service/**: Business logic that coordinates between handlers and db.

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

## Installation

See [macOS Daemon Installation](../docs/macos-daemon-installation.md)

## Development

Requires OCaml version 5.4.0

```bash
opam switch create connections 5.4.0
```

Install dependencies using opam. Note that [tapak](https://github.com/syaiful6/tapak) is not published to opam and must be pinned first:

```bash
opam pin add tapak https://github.com/syaiful6/tapak.git#85aaf8baf068e921f86a90be653a137ff58c2db6 -y
opam install . --deps-only
```

- Building: `dune build`
- Running: `dune exec connections-server`
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