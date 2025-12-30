type feed_info = { url : string; title : string option }
type person_info = { name : string; feeds : feed_info list; tags : string list }
type import_error = { url : string; error : string }

type preview_response = {
  people : person_info list;
  errors : import_error list;
}

type confirm_request = { people : person_info list }

type confirm_response = {
  created_people : int;
  created_feeds : int;
  created_tags : int;
}

val preview_response_to_json : preview_response -> Yojson.Safe.t
val confirm_request_of_json : Yojson.Safe.t -> confirm_request
val confirm_response_to_json : confirm_response -> Yojson.Safe.t

val preview :
  sw:Eio.Switch.t ->
  env:Eio_unix.Stdenv.base ->
  string ->
  (preview_response, string) result

val confirm : confirm_request -> (confirm_response, string) result
