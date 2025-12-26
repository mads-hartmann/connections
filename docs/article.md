# Article

Articles are entries from RSS feeds. They are created automatically when feeds are fetched.

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | int | Unique identifier |
| `feed_id` | int | ID of the parent feed |
| `title` | string (optional) | Article title |
| `url` | string | Article URL |
| `published_at` | string (optional) | Publication timestamp |
| `content` | string (optional) | Article content/summary |
| `author` | string (optional) | Author name |
| `image_url` | string (optional) | Featured image URL |
| `created_at` | string | When the article was added |
| `read_at` | string (optional) | When marked as read, null if unread |
| `tags` | array | List of tags (see [tag.md](tag.md)) |

## Endpoints

### List all articles

```
GET /articles
```

Query parameters:
- `page` (int, default: 1) - Page number
- `per_page` (int, default: 20) - Items per page
- `unread` (bool, optional) - Filter to unread articles only
- `tag` (string, optional) - Filter by tag name

```bash
curl http://localhost:8080/articles
curl "http://localhost:8080/articles?unread=true"
curl "http://localhost:8080/articles?tag=tech"
curl "http://localhost:8080/articles?tag=tech&unread=true"
curl "http://localhost:8080/articles?page=1&per_page=20"
```

### List articles for a feed

```
GET /feeds/:feed_id/articles
```

```bash
curl http://localhost:8080/feeds/1/articles
curl "http://localhost:8080/feeds/1/articles?page=1&per_page=20"
```

### Get an article

```
GET /articles/:id
```

```bash
curl http://localhost:8080/articles/1
```

### Mark an article as read/unread

```
POST /articles/:id/read
```

Request body:
```json
{"read": true}
```

```bash
# Mark as read
curl -X POST http://localhost:8080/articles/1/read \
  -H "Content-Type: application/json" \
  -d '{"read": true}'

# Mark as unread
curl -X POST http://localhost:8080/articles/1/read \
  -H "Content-Type: application/json" \
  -d '{"read": false}'
```

### Mark all articles in a feed as read

```
POST /feeds/:feed_id/articles/mark-all-read
```

Returns the count of articles marked as read.

```bash
curl -X POST http://localhost:8080/feeds/1/articles/mark-all-read
```

### Delete an article

```
DELETE /articles/:id
```

```bash
curl -X DELETE http://localhost:8080/articles/1
```
