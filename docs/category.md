# Category

Categories allow organizing persons into groups.

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | int | Unique identifier |
| `name` | string | Category name |

## Endpoints

### List categories

```
GET /categories
```

Query parameters:
- `page` (int, default: 1) - Page number
- `per_page` (int, default: 20) - Items per page

```bash
curl http://localhost:8080/categories
```

### Get a category

```
GET /categories/:id
```

```bash
curl http://localhost:8080/categories/1
```

### Create a category

```
POST /categories
```

Request body:
```json
{"name": "Friends"}
```

```bash
curl -X POST http://localhost:8080/categories \
  -H "Content-Type: application/json" \
  -d '{"name": "Friends"}'
```

### Delete a category

```
DELETE /categories/:id
```

```bash
curl -X DELETE http://localhost:8080/categories/1
```

## Person-Category Association

See [person.md](person.md) for endpoints to add/remove categories from persons.
