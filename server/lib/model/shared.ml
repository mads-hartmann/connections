open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type error_response = { error : string } [@@deriving yojson]

let error_to_json msg = yojson_of_error_response { error = msg }

module Paginated = struct
  type 'a t = {
    data : 'a list;
    page : int;
    per_page : int;
    total : int;
    total_pages : int;
  }

  let to_json item_to_json response =
    `Assoc
      [
        ("data", `List (List.map item_to_json response.data));
        ("page", `Int response.page);
        ("per_page", `Int response.per_page);
        ("total", `Int response.total);
        ("total_pages", `Int response.total_pages);
      ]

  let make ~data ~page ~per_page ~total =
    let total_pages = (total + per_page - 1) / per_page in
    { data; page; per_page; total; total_pages }
end
