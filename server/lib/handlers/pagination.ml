open Tapak

type pagination = { page : int; per_page : int }
type Request_guard.error += Invalid_pagination

let pagination_guard : pagination Request_guard.t =
 fun req ->
  let uri = Request.uri req in
  match
    (Uri.get_query_param uri "page", Uri.get_query_param uri "per_page")
  with
  | Some page_str, Some per_page_str -> (
      match (int_of_string_opt page_str, int_of_string_opt per_page_str) with
      | Some page, Some per_page
        when page > 0 && per_page > 0 && per_page <= 100 ->
          Ok { page; per_page }
      | _ -> Error Invalid_pagination)
  | Some page_str, None -> (
      match int_of_string_opt page_str with
      | Some page when page > 0 -> Ok { page; per_page = 20 }
      | _ -> Error Invalid_pagination)
  | None, Some per_page_str -> (
      match int_of_string_opt per_page_str with
      | Some per_page when per_page > 0 && per_page <= 100 ->
          Ok { page = 1; per_page }
      | _ -> Error Invalid_pagination)
  | None, None -> Ok { page = 1; per_page = 20 }
