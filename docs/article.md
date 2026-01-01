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
| `image_url` | string (optional) | Featured image URL from RSS feed |
| `created_at` | string | When the article was added |
| `read_at` | string (optional) | When marked as read, null if unread |
| `tags` | array | List of tags (see [tag.md](tag.md)) |
| `og_title` | string (optional) | Open Graph title |
| `og_description` | string (optional) | Open Graph description |
| `og_image` | string (optional) | Open Graph image URL |
| `og_site_name` | string (optional) | Open Graph site name |
| `og_fetched_at` | string (optional) | When OG metadata was last fetched |
| `og_fetch_error` | string (optional) | Error message if OG fetch failed |

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

### List articles for a person

```
GET /persons/:person_id/articles
```

Returns all articles from all feeds belonging to this person.

Query parameters:
- `page` (int, default: 1) - Page number
- `per_page` (int, default: 20) - Items per page
- `unread` (bool, optional) - Filter to unread articles only

```bash
curl http://localhost:8080/persons/1/articles
curl "http://localhost:8080/persons/1/articles?unread=true"
curl "http://localhost:8080/persons/1/articles?page=1&per_page=10"
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

### Mark all articles as read

```
POST /articles/mark-all-read
```

Marks all unread articles as read across all feeds. Returns the count of articles marked as read.

```bash
curl -X POST http://localhost:8080/articles/mark-all-read
```

### Refresh article metadata

```
POST /articles/:id/refresh-metadata
```

Fetches Open Graph metadata from the article's URL and updates the article. This is synchronous and returns the updated article.

```bash
curl -X POST http://localhost:8080/articles/1/refresh-metadata
```

### Delete an article

```
DELETE /articles/:id
```

```bash
curl -X DELETE http://localhost:8080/articles/1
```

## Open Graph Metadata

Articles can have Open Graph metadata extracted from their URLs. This happens:

1. **Automatically** - A background job runs every 5 minutes and processes up to 50 articles that haven't been fetched yet
2. **On demand** - Use the `POST /articles/:id/refresh-metadata` endpoint

Failed fetches are retried after 24 hours. The `og_fetch_error` field contains the error message if the fetch failed.
