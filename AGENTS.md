# OCaml Code Conventions

## Core Principles

### 1. Option and Result Combinators

Replace verbose pattern matching with combinators:

```ocaml
(* Bad *)
match get_value () with
| Some x -> Some (x + 1)
| None -> None

(* Good *)
Option.map (fun x -> x + 1) (get_value ())
```

Prefer: `Option.map`, `Option.bind`, `Option.value`, `Option.iter`, `Option.fold`, `Result.map`, `Result.bind`, `Result.map_error`, `Result.join`

Use `Option.get` sparingly and only when None is provably impossible.

### 2. Monadic Syntax with let* and let+

Use `let*` (bind) and `let+` (map) for cleaner chaining:

```ocaml
(* Bad - nested matches *)
match fetch_user id with
| Ok user ->
    (match fetch_permissions user with
     | Ok perms -> Ok perms
     | Error e -> Error e)
| Error e -> Error e

(* Good *)
let open Result.Syntax in
let* user = fetch_user id in
let* perms = fetch_permissions user in
Ok perms
```

Mixing map and bind with `and+`:

```ocaml
let open Result.Syntax in
let+ user = fetch_user id
and+ config = fetch_config () in
(user, config)
```

### 3. Pattern Matching Over Nested Conditionals

```ocaml
(* Bad *)
if x > 0 then
  if x < 10 then "small"
  else if x < 100 then "medium"
  else "large"
else "negative"

(* Good *)
match x with
| x when x < 0 -> "negative"
| x when x < 10 -> "small"
| x when x < 100 -> "medium"
| _ -> "large"
```

Use tuple matching for boolean conditions:

```ocaml
match condition1, condition2 with
| true, true -> handle_both ()
| true, false -> handle_first ()
| false, _ -> handle_neither ()
```

### 4. Factor Out Common Code

Extract repeated patterns into helper functions:

```ocaml
(* Bad - repeated error formatting *)
raise (Invalid_argument (Printf.sprintf "Expected %s but got %s" expected actual))

(* Good - factored helper *)
let type_error ~expected ~actual =
  Invalid_argument (Printf.sprintf "Expected %s but got %s" expected actual)

raise (type_error ~expected:"string" ~actual:"int")
```

### 5. Module Structure

Use abstract type `t` pattern with accessors:

```ocaml
module User : sig
  type t

  val create : name:string -> email:string -> t
  val name : t -> string
  val email : t -> string
  val pp : Format.formatter -> t -> unit
  val equal : t -> t -> bool
end = struct
  type t = { name : string; email : string }

  let create ~name ~email = { name; email }
  let name t = t.name
  let email t = t.email
  let pp fmt t = Format.fprintf fmt "%s <%s>" t.name t.email
  let equal a b = String.equal a.name b.name && String.equal a.email b.email
end
```

Avoid generic module names: `Util`, `Utils`, `Helpers`, `Common`, `Misc`

Use specific names: `String_ext`, `File_io`, `Json_codec`

### 6. Labeled Arguments

Prefer labeled arguments for clarity:

```ocaml
(* Bad *)
let create name email age = ...

(* Good *)
let create ~name ~email ~age = ...
```

### 7. Naming Complex Arguments

Instead of inline complex expressions, bind them to named variables:

```ocaml
(* Bad *)
let temp = f x y z "large expression" "other large expression" in

(* Good *)
let t = "large expression"
and u = "other large expression" in
let temp = f x y z t u in
```

### 8. Naming Anonymous Functions

For complex iterator arguments, define the function with a `let` binding:

```ocaml
(* Bad *)
List.map
  (function x ->
    blabla
    blabla
    blabla)
  l

(* Good *)
let f x =
  blabla
  blabla
  blabla in
List.map f l
```

### 9. Every Main Type Should Have

- `pp` function (pretty-printer)
- `equal` function
- Explicit type annotations on public interfaces

## Red Flags

- Match expressions that just rewrap: `match x with Some v -> Some (f v) | None -> None`
- Nested matches on Result/Option - use `let*`/`let+` instead
- Repeated error messages - factor into helper functions
- Deep if/then/else chains - convert to pattern matching
- Modules named Util/Helper
- Exposed record types without accessors
- Missing `pp` functions on main types
- Unlabeled boolean parameters: `create name true false`
