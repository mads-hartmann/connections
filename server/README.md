# Connections API Server

API backed by SQlite.

It's written in OCaml (>= 5.4.0) and takes advantage of the new effects system which has influenced the library selection. It uses [tapak](https://github.com/syaiful6/tapak) as the web framework.

TODO: Finish with the rest of the libraries and what they're used for.

## Configuration

TODO: Convert this into a table that includes a merging of the CLI options and the ENV VAR options


| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Port to run the server on |
| `DB_PATH` | `connections.db` | Path to SQLite database file |

## Development

Requires OCaml version 5.4.0

```bash
opam switch create connections 5.4.0
```

Install dependencies using opam:

```bash
opam install . --deps-only
```

- Building: `dune build`
- Formatting: `dune fmt`
- Tests: `dune test`
- Updating snapshots `dune exec server/bin/update_snapshots.exe`

## Tests

TODO: Write about the other kinds of test there are 

- E2E tests start the server with `server/test/data/test.db` and compare API responses against JSON snapshots in `server/test/data/snapshots/` - this is only meant as regression tests that are helpful when I refactor the code.