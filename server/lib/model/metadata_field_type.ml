open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type t = Bluesky | Email | GitHub | LinkedIn | Mastodon | Website | X
[@@deriving yojson]

let id = function
  | Bluesky -> 1
  | Email -> 2
  | GitHub -> 3
  | LinkedIn -> 4
  | Mastodon -> 5
  | Website -> 6
  | X -> 7

let name = function
  | Bluesky -> "Bluesky"
  | Email -> "Email"
  | GitHub -> "GitHub"
  | LinkedIn -> "LinkedIn"
  | Mastodon -> "Mastodon"
  | Website -> "Website"
  | X -> "X"

let of_id = function
  | 1 -> Some Bluesky
  | 2 -> Some Email
  | 3 -> Some GitHub
  | 4 -> Some LinkedIn
  | 5 -> Some Mastodon
  | 6 -> Some Website
  | 7 -> Some X
  | _ -> None

let all = [ Bluesky; Email; GitHub; LinkedIn; Mastodon; Website; X ]

type with_id = { id : int; name : string } [@@deriving yojson]

let to_json_with_id t = yojson_of_with_id { id = id t; name = name t }

let all_to_json () =
  `List (List.map (fun t -> to_json_with_id t) all)
