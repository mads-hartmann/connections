# Lwt → Eio Migration Plan

Migration from Lwt-based async to Eio effects-based concurrency.

## Dependencies Changes

| Remove | Add |
|--------|-----|
| `dream` | `tapak` (pin from GitHub) |
| `caqti-lwt` | `caqti-eio` |
| `cohttp-lwt-unix` | `piaf` (tapak dependency) |
| `lwt` | `eio`, `eio_main` |
| `alcotest-lwt` | `alcotest` (direct style) |

## Migration Phases

### Phase 1: Update Dependencies

1. Update `dune-project` with new dependencies
2. Pin tapak: `opam pin add tapak https://github.com/syaiful6/tapak.git`
3. Install: `opam install . --deps-only`

### Phase 2: Database Layer (`lib/db/`)

Convert from `Caqti_lwt_unix` to `Caqti_eio`:

**Before:**
```ocaml
open Lwt.Syntax
let* result = Caqti_lwt_unix.Pool.use (fun (module Db : Caqti_lwt.CONNECTION) -> ...) pool
```

**After:**
```ocaml
let result = Caqti_eio_unix.Pool.use (fun (module Db : Caqti_eio.CONNECTION) -> ...) pool
```

Files:
- `pool.ml` - Pool type to `Caqti_eio_unix.Pool.t`, add `sw` parameter
- `person.ml` - Direct style, remove `Lwt.Syntax`
- `rss_feed.ml` - Direct style
- `article.ml` - Direct style
- `category.ml` - Direct style

### Phase 3: HTTP Client (`lib/feed_fetcher.ml`)

Replace `Cohttp_lwt_unix.Client` with `Piaf.Client`:

**Before:**
```ocaml
let* response, body = Cohttp_lwt_unix.Client.get (Uri.of_string url) in
let* body_str = Cohttp_lwt.Body.to_string body in
```

**After:**
```ocaml
let response = Piaf.Client.Oneshot.get ~sw env (Uri.of_string url) in
match response with
| Ok response -> Piaf.Body.to_string response.body
| Error _ -> ...
```

### Phase 4: Scheduler (`lib/scheduler.ml`)

Replace Lwt async with Eio fibers:

**Before:**
```ocaml
Lwt.async (fun () -> ...)
Lwt_unix.sleep 5.0
```

**After:**
```ocaml
Eio.Fiber.fork_daemon ~sw (fun () -> ...)
Eio.Time.sleep clock 5.0
```

Scheduler needs `env` for clock and network access.

### Phase 5: OPML Import (`lib/opml_import.ml`)

Replace Lwt concurrency primitives:

**Before:**
```ocaml
let semaphore = Lwt_mutex.create () in
Lwt_list.map_p fetch_one entries
```

**After:**
```ocaml
let semaphore = Eio.Semaphore.make max_concurrent_fetches in
Eio.Fiber.List.map ~max_fibers:max_concurrent_fetches fetch_one entries
```

### Phase 6: Web Framework (`lib/router.ml`, `lib/handlers/`)

Replace Dream with Tapak:

**Router:**
```ocaml
(* Before - Dream *)
Dream.router [
  Dream.get "/persons" Handlers.Person.list;
  Dream.get "/persons/:id" Handlers.Person.get;
]

(* After - Tapak *)
let open Tapak.Router in
routes [
  get (s "persons") |> unit |> into Handlers.Person.list;
  get (s "persons" / int64) |> into Handlers.Person.get;
]
```

**Handlers:**
- Receive parsed parameters directly (not `Dream.request`)
- Use `Tapak.Request` and `Tapak.Response` APIs
- Direct style (no `Lwt.return`)

Files:
- `router.ml`
- `handlers/response.ml`
- `handlers/person.ml`
- `handlers/rss_feed.ml`
- `handlers/article.ml`
- `handlers/category.ml`
- `handlers/import.ml`

### Phase 7: Main Entry Point (`bin/main.ml`)

**Before:**
```ocaml
Lwt_main.run begin
  let open Lwt.Syntax in
  let* () = Db.Pool.init db_path in
  ...
end
```

**After:**
```ocaml
Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  Db.Pool.init ~sw ~env db_path;
  ...
  Tapak.Server.run_with ~config ~env app
```

### Phase 8: Tests (`test/`)

- Remove `Alcotest_lwt`, use plain `Alcotest`
- Direct style (no `Lwt.return_unit`)
- Stub/simplify tests initially

Files:
- `test_main.ml`
- `test_helpers.ml`
- `test_person.ml`
- `test_rss_feed.ml`
- `test_article.ml`
- `test_feed_fetcher.ml`
- `test_opml_parser.ml`
- `test_utils.ml`

### Phase 9: Logging

Replace Dream logging with `Logs`:

```ocaml
(* Before *)
Dream.log "Starting server on port %d" port
Dream.error (fun log -> log "Error: %s" msg)

(* After *)
Logs.info (fun m -> m "Starting server on port %d" port)
Logs.err (fun m -> m "Error: %s" msg)
```

## Files Summary

| File | Changes |
|------|---------|
| `dune-project` | Update dependencies |
| `server/lib/dune` | Update libraries |
| `server/bin/dune` | Update libraries |
| `server/test/dune` | Update libraries |
| `server/lib/db/pool.ml` | Caqti_eio, env threading |
| `server/lib/db/person.ml` | Direct style |
| `server/lib/db/rss_feed.ml` | Direct style |
| `server/lib/db/article.ml` | Direct style |
| `server/lib/db/category.ml` | Direct style |
| `server/lib/feed_fetcher.ml` | Piaf client, direct style |
| `server/lib/scheduler.ml` | Eio fibers, clock |
| `server/lib/opml_import.ml` | Eio.Semaphore, direct style |
| `server/lib/router.ml` | Tapak routing |
| `server/lib/handlers/response.ml` | Tapak response helpers |
| `server/lib/handlers/person.ml` | Tapak handlers |
| `server/lib/handlers/rss_feed.ml` | Tapak handlers |
| `server/lib/handlers/article.ml` | Tapak handlers |
| `server/lib/handlers/category.ml` | Tapak handlers |
| `server/lib/handlers/import.ml` | Tapak handlers |
| `server/bin/main.ml` | Eio_main, Tapak server |
| `server/test/test_main.ml` | Alcotest (no Lwt) |
| `server/test/test_helpers.ml` | Direct style |
| `server/test/test_*.ml` | Stub/simplify |

## Scope

- ~20 files to modify
- ~2500 lines affected
- Database layer: ~800 lines
- Handlers: ~400 lines
- Feed fetcher + scheduler + import: ~400 lines
- Tests: ~600 lines (stubbed initially)
- Router + main: ~200 lines

## Risk Areas

1. **Tapak is experimental** - API may have rough edges
2. **Piaf client API** - Less documented than cohttp
3. **Caqti-eio** - Less battle-tested than caqti-lwt
4. **Test coverage** - Stubbing tests means temporary regression risk
