open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type t =
  | Bluesky
  | Email
  | GitHub
  | LinkedIn
  | Mastodon
  | Website
  | X
  | YouTube
  | Other
[@@deriving yojson]

let id = function
  | Bluesky -> 1
  | Email -> 2
  | GitHub -> 3
  | LinkedIn -> 4
  | Mastodon -> 5
  | Website -> 6
  | X -> 7
  | YouTube -> 9
  | Other -> 8

let name = function
  | Bluesky -> "Bluesky"
  | Email -> "Email"
  | GitHub -> "GitHub"
  | LinkedIn -> "LinkedIn"
  | Mastodon -> "Mastodon"
  | Website -> "Website"
  | X -> "X"
  | YouTube -> "YouTube"
  | Other -> "Other"

let of_id = function
  | 1 -> Some Bluesky
  | 2 -> Some Email
  | 3 -> Some GitHub
  | 4 -> Some LinkedIn
  | 5 -> Some Mastodon
  | 6 -> Some Website
  | 7 -> Some X
  | 9 -> Some YouTube
  | 8 -> Some Other
  | _ -> None

let all =
  [ Bluesky; Email; GitHub; LinkedIn; Mastodon; Website; X; YouTube; Other ]

type with_id = { id : int; name : string } [@@deriving yojson]

let to_json_with_id t = yojson_of_with_id { id = id t; name = name t }
let all_to_json () = `List (List.map (fun t -> to_json_with_id t) all)
let pp fmt t = Format.fprintf fmt "%s" (name t)

let equal a b =
  match (a, b) with
  | Bluesky, Bluesky -> true
  | Email, Email -> true
  | GitHub, GitHub -> true
  | LinkedIn, LinkedIn -> true
  | Mastodon, Mastodon -> true
  | Website, Website -> true
  | X, X -> true
  | YouTube, YouTube -> true
  | Other, Other -> true
  | _ -> false
