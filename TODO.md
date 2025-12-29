# TODO

## Profile Image Feature

### Database Migration
- [ ] Migrate existing test database (`server/test/data/test.db`) to include new columns:
  - `profile_image_url TEXT`
  - `metadata_updated_at TEXT`
- [ ] Update E2E test snapshots after migration

### E2E Tests
- [ ] E2E tests currently fail because test database schema is outdated
- [ ] Need to either recreate test.db or run ALTER TABLE statements

### Type Inference Issue
- [ ] Investigate strange type inference issue in `server/lib/handlers/metadata.ml`
  - The `|>` operator with `Tapak.Router.request` causes incorrect type inference
  - Workaround: use explicit function application instead of pipe operator
  - May be related to module shadowing or OCaml type inference edge case
