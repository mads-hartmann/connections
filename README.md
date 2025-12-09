# Connections Server

A simple OCaml web server for managing connections (people) with SQLite storage.

## Development

Install dependencies using opam:

```bash
opam install . --deps-only
```

Building

```bash
dune build
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

## API Endpoints

### List Persons (Paginated)

```bash
GET /persons?page=1&per_page=10
```

Response:
```json
{
  "data": [
    {"id": 1, "name": "Alice"},
    {"id": 2, "name": "Bob"}
  ],
  "page": 1,
  "per_page": 10,
  "total": 2,
  "total_pages": 1
}
```

### Get Person

```bash
GET /persons/:id
```

Response:
```json
{"id": 1, "name": "Alice"}
```

### Create Person

```bash
POST /persons
Content-Type: application/json

{"name": "Alice"}
```

Response (201 Created):
```json
{"id": 1, "name": "Alice"}
```

### Update Person

```bash
PUT /persons/:id
Content-Type: application/json

{"name": "Alice Updated"}
```

Response:
```json
{"id": 1, "name": "Alice Updated"}
```

### Delete Person

```bash
DELETE /persons/:id
```

Response: 204 No Content

## Error Responses

Errors are returned as JSON with an `error` field:

```json
{"error": "Person not found"}
```

Common HTTP status codes:
- `400 Bad Request` - Invalid input
- `404 Not Found` - Resource not found
- `500 Internal Server Error` - Database or server error

