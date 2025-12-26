# Import

Import feeds from OPML files. The import process has two steps: preview and confirm.

## OPML Import

### Preview import

Parse an OPML file and return a preview of what will be imported. Each outline with feeds becomes a person. OPML folder structure is converted to tags.

```
POST /import/opml/preview
```

Send the OPML XML as the request body.

```bash
curl -X POST http://localhost:8080/import/opml/preview \
  -H "Content-Type: application/xml" \
  --data-binary @feeds.opml
```

Response:
```json
{
  "people": [
    {
      "name": "Person Name",
      "feeds": [{"url": "https://example.com/feed.xml", "title": "Feed Title"}],
      "tags": ["Tech", "Blogs"]
    }
  ],
  "errors": []
}
```

### Confirm import

Create the persons, feeds, and tags from a preview.

```
POST /import/opml/confirm
```

Request body:
```json
{
  "people": [
    {
      "name": "Person Name",
      "feeds": [
        {"url": "https://example.com/feed.xml", "title": "Feed Title"}
      ],
      "tags": ["Tech"]
    }
  ]
}
```

```bash
curl -X POST http://localhost:8080/import/opml/confirm \
  -H "Content-Type: application/json" \
  -d '{"people": [{"name": "John", "feeds": [{"url": "https://example.com/feed.xml", "title": "Blog"}], "tags": ["Tech"]}]}'
```

Response:
```json
{
  "created_people": 1,
  "created_feeds": 1,
  "created_tags": 1
}
```
