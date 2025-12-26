# Tag

Tags allow organizing persons, feeds, and articles. When feeds are fetched, tags are automatically extracted from RSS/Atom category elements and associated with articles.

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | int | Unique identifier |
| `name` | string | Tag name (unique) |

## Endpoints

### List tags

```
GET /tags
```

Query parameters:
- `page` (int, default: 1) - Page number
- `per_page` (int, default: 20) - Items per page

```bash
curl http://localhost:8080/tags
```

### Get a tag

```
GET /tags/:id
```

```bash
curl http://localhost:8080/tags/1
```

### Create a tag

```
POST /tags
```

Request body:
```json
{"name": "tech"}
```

```bash
curl -X POST http://localhost:8080/tags \
  -H "Content-Type: application/json" \
  -d '{"name": "tech"}'
```

### Rename a tag

```
PATCH /tags/:id
```

Request body:
```json
{"name": "technology"}
```

```bash
curl -X PATCH http://localhost:8080/tags/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "technology"}'
```

### Delete a tag

```
DELETE /tags/:id
```

```bash
curl -X DELETE http://localhost:8080/tags/1
```

## Person-Tag Association

### List tags for a person

```
GET /persons/:person_id/tags
```

```bash
curl http://localhost:8080/persons/1/tags
```

### Add a tag to a person

```
POST /persons/:person_id/tags/:tag_id
```

```bash
curl -X POST http://localhost:8080/persons/1/tags/1
```

### Remove a tag from a person

```
DELETE /persons/:person_id/tags/:tag_id
```

```bash
curl -X DELETE http://localhost:8080/persons/1/tags/1
```

## Feed-Tag Association

Feed tags are inherited by articles when feeds are fetched.

### List tags for a feed

```
GET /feeds/:feed_id/tags
```

```bash
curl http://localhost:8080/feeds/1/tags
```

### Add a tag to a feed

```
POST /feeds/:feed_id/tags/:tag_id
```

```bash
curl -X POST http://localhost:8080/feeds/1/tags/1
```

### Remove a tag from a feed

```
DELETE /feeds/:feed_id/tags/:tag_id
```

```bash
curl -X DELETE http://localhost:8080/feeds/1/tags/1
```

## Article-Tag Association

Articles automatically include their tags in responses. Tags are also extracted from RSS/Atom category elements when feeds are fetched.

### Add a tag to an article

```
POST /articles/:article_id/tags/:tag_id
```

```bash
curl -X POST http://localhost:8080/articles/1/tags/1
```

### Remove a tag from an article

```
DELETE /articles/:article_id/tags/:tag_id
```

```bash
curl -X DELETE http://localhost:8080/articles/1/tags/1
```

## Tag Extraction

When feeds are fetched, tags are automatically extracted from:
- RSS2: `<category>` elements on items
- Atom: `<category term="...">` elements on entries

These tags are auto-created if they don't exist and associated with the article.
