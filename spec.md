# URI Voting Feature Specification

## Problem Statement

Users want to vote URIs up or down to track their preferences. This is a single-user system, so votes represent personal sentiment rather than aggregated scores.

## Requirements

### Data Model

- Add a `vote` field to URIs with three possible states:
  - `null` - no vote (default)
  - `1` - upvoted
  - `-1` - downvoted
- Store as `voted_at` timestamp (nullable) and `vote` integer (nullable) in the database

### API Endpoints

**New endpoint:** `POST /uris/:id/vote`

Request body:
```json
{ "vote": 1 }    // upvote
{ "vote": -1 }   // downvote
{ "vote": null } // remove vote
```

Response: Returns the updated URI JSON.

Behavior:
- Voting the same direction as current vote = no change (idempotent)
- Voting opposite direction = changes the vote
- Voting `null` = removes the vote

**Modified endpoint:** `GET /uris`

Add query parameters:
- `upvoted=true` - filter to show only upvoted URIs
- `downvoted=true` - filter to show only downvoted URIs

### Raycast Extension

**URI list display:**
- Show vote indicator icon next to URIs in list view
- Upvoted: arrow-up icon
- Downvoted: arrow-down icon
- No vote: no icon

**Actions:**
- Add "Upvote" action (Cmd+U)
- Add "Downvote" action (Cmd+Shift+U)
- Add "Remove Vote" action (Cmd+Opt+U, when URI has a vote)

**Filtering:**
- Add filter options in the view dropdown:
  - "Upvoted"
  - "Downvoted"

## Acceptance Criteria

1. URIs can be upvoted via API
2. URIs can be downvoted via API
3. Votes can be removed via API
4. Voting same direction twice is idempotent (no change)
5. URI JSON includes `vote` and `voted_at` fields
6. URIs can be filtered by upvoted/downvoted status
7. Raycast shows vote state icon in URI list
8. Raycast has upvote/downvote/remove actions
9. Raycast can filter to show upvoted/downvoted URIs
10. All existing tests pass
11. New functionality has test coverage

## Implementation Approach

### Phase 1: Database & Model

1. Add `vote` (INTEGER, nullable) and `voted_at` (TEXT, nullable) columns to uris table in schema.sql
2. Add index on vote column
3. Update `Model.Uri_entry` type to include `vote` and `voted_at` fields
4. Update `Db.Uri_store` row type and queries to handle new fields

### Phase 2: Service & API

5. Add `vote` function to `Db.Uri_store`
6. Add `vote` function to `Service.Uri`
7. Add `POST /uris/:id/vote` handler in `Handlers.Uri_handler`
8. Update `list_all` to support `upvoted` and `downvoted` query filters

### Phase 3: Raycast Extension

9. Update `Uri` TypeScript interface with `vote` and `voted_at` fields
10. Add `voteUri` API function
11. Add vote actions to URI action panel
12. Add vote state icon to URI list items
13. Add upvoted/downvoted filter options in view dropdown

### Phase 4: Testing & Verification

14. Add OCaml tests for vote functionality
15. Update test database with new columns
16. Regenerate E2E test snapshots
17. Verify Raycast extension builds and lints
