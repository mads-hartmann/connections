# Connections Server

A simple OCaml web server for managing connections (people) with SQLite storage.

## Development

Install dependencies using opam:

```bash
opam install . --deps-only
```

### Building

```bash
dune build
```

### Formatting

Format all OCaml code:

```bash
dune fmt
```

Or format a specific file:

```bash
ocamlformat -i server/lib/person.ml
```

For editor integration, install the [OCaml Platform](https://marketplace.visualstudio.com/items?itemName=ocamllabs.ocaml-platform) extension. It will automatically format on save when `ocamlformat` is installed and a `.ocamlformat` file exists.

### Running

```bash
dune exec connections-server
```

Or run with custom configuration:

```bash
PORT=3000 DB_PATH=mydata.db dune exec connections-server
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Port to run the server on |
| `DB_PATH` | `connections.db` | Path to SQLite database file |

## API Documentation

The API documentation is automatically generated and available at runtime:

- **OpenAPI Spec**: `http://localhost:8080/openapi.json`
- **Interactive Docs**: `http://localhost:8080/docs`

You can also import the OpenAPI spec into tools like [Swagger Editor](https://editor.swagger.io/) or [Postman](https://www.postman.com/).
