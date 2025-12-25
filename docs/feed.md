# Feed

An RSS feed belongs to a person and contains articles. Feeds are periodically fetched by a background scheduler.

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | int | Unique identifier |
| `person_id` | int | ID of the person this feed belongs to |
| `url` | string | Feed URL |
| `title` | string (optional) | Feed title |
| `created_at` | string | ISO 8601 timestamp |
| `last_fetched_at` | string (optional) | Last successful fetch timestamp |

## Endpoints

### List all feeds

```
GET /feeds
```

Query parameters:
- `page` (int, default: 1) - Page number
- `per_page` (int, default: 20) - Items per page

```bash
curl http://localhost:8080/feeds
curl "http://localhost:8080/feeds?page=1&per_page=10"
```

### List feeds for a person

```
GET /persons/:person_id/feeds
```

```bash
curl http://localhost:8080/persons/1/feeds
curl "http://localhost:8080/persons/1/feeds?page=1&per_page=5"
```

### Get a feed

```
GET /feeds/:id
```

```bash
curl http://localhost:8080/feeds/1
```

### Create a feed

```
POST /persons/:person_id/feeds
```

Request body:
```json
{
  "person_id": 1,
  "url": "https://example.com/feed.xml",
  "title": "Example Feed"
}
```

The `person_id` in the body must match the URL parameter.

```bash
curl -X POST http://localhost:8080/persons/1/feeds \
  -H "Content-Type: application/json" \
  -d '{"person_id": 1, "url": "https://example.com/feed.xml", "title": "Example Feed"}'
```

### Update a feed

```
PUT /feeds/:id
```

Request body (all fields optional):
```json
{
  "url": "https://example.com/new-feed.xml",
  "title": "Updated Title"
}
```

```bash
curl -X PUT http://localhost:8080/feeds/1 \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/new-feed.xml", "title": "Updated Feed Title"}'
```

### Delete a feed

```
DELETE /feeds/:id
```

```bash
curl -X DELETE http://localhost:8080/feeds/1
```

### Refresh a feed

Manually trigger a feed fetch to update articles.

```
POST /feeds/:id/refresh
```

```bash
curl -X POST http://localhost:8080/feeds/1/refresh
```
