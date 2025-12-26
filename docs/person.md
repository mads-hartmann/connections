# Person

A person represents an individual in your social graph. Each person can have multiple RSS feeds and be associated with multiple tags.

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | int | Unique identifier |
| `name` | string | Person's name |

When listing persons, additional computed fields are included:

| Field | Type | Description |
|-------|------|-------------|
| `feed_count` | int | Number of RSS feeds |
| `article_count` | int | Total articles across all feeds |

## Endpoints

### List persons

```
GET /persons
```

Query parameters:
- `page` (int, default: 1) - Page number
- `per_page` (int, default: 20) - Items per page
- `query` (string, optional) - Filter by name

```bash
curl http://localhost:8080/persons
curl "http://localhost:8080/persons?page=1&per_page=5"
curl "http://localhost:8080/persons?query=john"
```

### Get a person

```
GET /persons/:id
```

```bash
curl http://localhost:8080/persons/1
```

### Create a person

```
POST /persons
```

Request body:
```json
{"name": "John Doe"}
```

```bash
curl -X POST http://localhost:8080/persons \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe"}'
```

### Update a person

```
PUT /persons/:id
```

Request body:
```json
{"name": "John Updated"}
```

```bash
curl -X PUT http://localhost:8080/persons/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "John Updated"}'
```

### Delete a person

```
DELETE /persons/:id
```

```bash
curl -X DELETE http://localhost:8080/persons/1
```

## Tags

Persons can be organized with tags. See [tag.md](tag.md) for tag management.

### List tags for a person

```
GET /persons/:id/tags
```

```bash
curl http://localhost:8080/persons/1/tags
```

### Add a tag to a person

```
POST /persons/:person_id/tags/:tag_id
```

```bash
curl -X POST http://localhost:8080/persons/1/tags/2
```

### Remove a tag from a person

```
DELETE /persons/:person_id/tags/:tag_id
```

```bash
curl -X DELETE http://localhost:8080/persons/1/tags/2
```
