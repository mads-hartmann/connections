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

Testing

```bash
dune test
```

### E2E Snapshot Tests

E2E tests start the server with `server/test/data/test.db` and compare API responses against JSON snapshots in `server/test/data/snapshots/`.

Update snapshots after intentional API changes:

```bash
dune exec server/bin/update_snapshots.exe
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

### Add an RSS feed to a person

```bash
curl -X POST http://localhost:8080/persons/1/feeds \
  -H "Content-Type: application/json" \
  -d '{"person_id": 1, "url": "https://example.com/feed.xml", "title": "Example Feed"}'
```

### List all feeds for a person

```bash
curl http://localhost:8080/persons/1/feeds
```

With pagination:

```bash
curl "http://localhost:8080/persons/1/feeds?page=1&per_page=5"
```

### Get a specific feed by ID

```bash
curl http://localhost:8080/feeds/1
```

### Update a feed

```bash
curl -X PUT http://localhost:8080/feeds/1 \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/new-feed.xml", "title": "Updated Feed Title"}'
```

### Delete a feed

```bash
curl -X DELETE http://localhost:8080/feeds/1
```

### List articles for a feed

```bash
curl http://localhost:8080/feeds/1/articles
```

With pagination:

```bash
curl "http://localhost:8080/feeds/1/articles?page=1&per_page=20"
```

### List all articles

```bash
curl http://localhost:8080/articles
```

Filter to show only unread articles:

```bash
curl "http://localhost:8080/articles?unread=true"
```

### Get a specific article

```bash
curl http://localhost:8080/articles/1
```

### Mark an article as read

```bash
curl -X POST http://localhost:8080/articles/1/read \
  -H "Content-Type: application/json" \
  -d '{"read": true}'
```

### Mark an article as unread

```bash
curl -X POST http://localhost:8080/articles/1/read \
  -H "Content-Type: application/json" \
  -d '{"read": false}'
```

### Mark all articles in a feed as read

```bash
curl -X POST http://localhost:8080/feeds/1/articles/mark-all-read
```

### Delete an article

```bash
curl -X DELETE http://localhost:8080/articles/1
```
