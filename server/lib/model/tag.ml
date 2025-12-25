open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type t = { id : int; name : string } [@@deriving yojson]

let to_json = yojson_of_t
let of_json = t_of_yojson
let list_to_json tags = `List (List.map yojson_of_t tags)
let paginated_to_json response = Shared.Paginated.to_json yojson_of_t response
let error_to_json = Shared.error_to_json
