# Connections

This is my attempt and building this:

> I want this weird hybrid of an app that's somewhere between an RSS reader and a Contacts app. I want to be able to organise my social graph and also snoop in on everyone and what they're up to.

It's currently very rough, and I'm mostly building it as an exercise to see how good Ona is at building OCaml apps and trying to push my own limits when it comes to vibe ~~coding~~ engineering.

## API Usage

TODO: Move this to docs instead. Create a file for each "concepts" e.g. person.md, feed.md, and so on

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
