# Connections Server

A simple OCaml web server for managing connections (people) with SQLite storage.

## Development

Requires OCaml version 5.4.0

```bash
opam switch create connections 5.4.0
```

Install dependencies using opam:

```bash
opam install . --deps-only
```

Building

```bash
dune build
```

Formatting

```bash
dune fmt
```

Running

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

## API Usage

### Create a person

```bash
curl -X POST http://localhost:8080/persons \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe"}'
```

### List all persons

```bash
curl http://localhost:8080/persons
```

With pagination:

```bash
curl "http://localhost:8080/persons?page=1&per_page=5"
```

### Get a person by ID

```bash
curl http://localhost:8080/persons/1
```

### Update a person

```bash
curl -X PUT http://localhost:8080/persons/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "John Updated"}'
```

### Delete a person

```bash
curl -X DELETE http://localhost:8080/persons/1
```
