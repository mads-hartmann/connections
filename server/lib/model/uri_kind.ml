type t = Blog | Video | Tweet | Book | Site | Unknown | Podcast | Paper

let to_string = function
  | Blog -> "blog"
  | Video -> "video"
  | Tweet -> "tweet"
  | Book -> "book"
  | Site -> "site"
  | Unknown -> "unknown"
  | Podcast -> "podcast"
  | Paper -> "paper"

let of_string = function
  | "blog" -> Some Blog
  | "video" -> Some Video
  | "tweet" -> Some Tweet
  | "book" -> Some Book
  | "site" -> Some Site
  | "unknown" -> Some Unknown
  | "podcast" -> Some Podcast
  | "paper" -> Some Paper
  | _ -> None

let of_string_exn s =
  match of_string s with
  | Some k -> k
  | None -> failwith (Printf.sprintf "Invalid URI kind: %s" s)

let to_id = function
  | Blog -> 1
  | Video -> 2
  | Tweet -> 3
  | Book -> 4
  | Site -> 5
  | Unknown -> 6
  | Podcast -> 7
  | Paper -> 8

let of_id = function
  | 1 -> Some Blog
  | 2 -> Some Video
  | 3 -> Some Tweet
  | 4 -> Some Book
  | 5 -> Some Site
  | 6 -> Some Unknown
  | 7 -> Some Podcast
  | 8 -> Some Paper
  | _ -> None

let of_id_exn id =
  match of_id id with
  | Some k -> k
  | None -> failwith (Printf.sprintf "Invalid URI kind id: %d" id)

let all = [ Blog; Video; Tweet; Book; Site; Unknown; Podcast; Paper ]

let pp fmt t = Format.fprintf fmt "%s" (to_string t)

let equal a b =
  match (a, b) with
  | Blog, Blog -> true
  | Video, Video -> true
  | Tweet, Tweet -> true
  | Book, Book -> true
  | Site, Site -> true
  | Unknown, Unknown -> true
  | Podcast, Podcast -> true
  | Paper, Paper -> true
  | _ -> false

let yojson_of_t t = `String (to_string t)

let t_of_yojson = function
  | `String s -> of_string_exn s
  | _ -> failwith "Expected string for URI kind"
