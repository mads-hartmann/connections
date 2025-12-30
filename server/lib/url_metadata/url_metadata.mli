module Feed = Types.Feed
module Author = Types.Author
module Content = Types.Content
module Site = Types.Site
module Extract_opengraph = Extract_opengraph

type t = Types.t = {
  url : string;
  feeds : Feed.t list;
  author : Author.t option;
  content : Content.t;
  site : Site.t;
  raw_json_ld : Yojson.Safe.t list;
}

val pp : Format.formatter -> t -> unit
val equal : t -> t -> bool
val extract : url:string -> html:string -> t
val extract_full : url:string -> html:string -> Json.full_response
val fetch : sw:Eio.Switch.t -> env:Eio_unix.Stdenv.base -> string -> (t, string) result
val fetch_full :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  string ->
  (Json.full_response, string) result
val to_json : t -> Yojson.Safe.t
val full_response_to_json : Json.full_response -> Yojson.Safe.t
