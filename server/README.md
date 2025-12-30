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

## Installation

See [macOS Daemon Installation](../docs/macos-daemon-installation.md)

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

## Module Conventions

This project follows a consistent module structure for all types. Each module that defines a primary type should:

1. **Use `.mli` interface files** to define the public API and enforce abstraction
2. **Define an abstract type `t`** as the module's primary type
3. **Provide accessor functions** instead of exposing record fields directly
4. **Include `pp` and `equal` functions** for debugging and testing

### Example

For a module `person.ml` defining a person type:

**`person.mli`** (interface):
```ocaml
type t

val create : name:string -> email:string -> t
val name : t -> string
val email : t -> string
val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
```

**`person.ml`** (implementation):
```ocaml
type t = { name : string; email : string }

let create ~name ~email = { name; email }
let name t = t.name
let email t = t.email
let pp fmt t = Format.fprintf fmt "%s <%s>" t.name t.email
let equal a b = String.equal a.name b.name && String.equal a.email b.email
```

### Benefits

- **Encapsulation**: Internal representation can change without breaking callers
- **Documentation**: The `.mli` file serves as documentation for the public API
- **Type safety**: Prevents accidental direct field access or construction
- **Testability**: `pp` and `equal` enable better test output and assertions

### Directory Structure

The project uses `(include_subdirs qualified)` in dune, so files in subdirectories become qualified modules:

- `model/person.ml` → `Model.Person`
- `db/article.ml` → `Db.Article`
- `url_metadata/types.ml` → `Url_metadata.Types`

## Tests

Run all tests with `dune test`. The test suite includes:

- **Unit tests** - JSON serialization, URL validation, feed parsing
- **Database tests** - CRUD operations for persons, feeds, articles using in-memory SQLite
- **E2E tests** - Start the server with `server/test/data/test.db` and compare API responses against JSON snapshots in `server/test/data/snapshots/`

To update E2E snapshots after intentional API changes:

```bash
dune exec server/bin/update_snapshots.exe
```