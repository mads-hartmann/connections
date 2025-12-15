open Lwt.Syntax

let list request =
  let page = max 1 (Response.parse_query_int "page" 1 request) in
  let per_page = min 100 (max 1 (Response.parse_query_int "per_page" 10 request)) in
  let query = Dream.query request "query" in
  let* result = Db.Person.list_with_counts ~page ~per_page ?query () in
  match result with
  | Error msg -> Lwt.return (Response.internal_error msg)
  | Ok paginated ->
      Lwt.return
        (Response.json_response (Model.Person.paginated_with_counts_to_json paginated))

let get request =
  match Response.parse_int_param "id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok id -> (
      let* result = Db.Person.get ~id in
      match result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok None -> Lwt.return (Response.not_found "Person not found")
      | Ok (Some person) ->
          Lwt.return (Response.json_response (Model.Person.to_json person)))

let create request =
  let* parsed = Response.parse_json_body Model.Person.create_request_of_yojson request in
  match parsed with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok { name } ->
      if String.trim name = "" then
        Lwt.return (Response.bad_request "Name cannot be empty")
      else
        let* result = Db.Person.create ~name in
        match result with
        | Error msg -> Lwt.return (Response.internal_error msg)
        | Ok person ->
            Lwt.return
              (Response.json_response ~status:`Created (Model.Person.to_json person))

let update request =
  match Response.parse_int_param "id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok id -> (
      let* parsed = Response.parse_json_body Model.Person.update_request_of_yojson request in
      match parsed with
      | Error msg -> Lwt.return (Response.bad_request msg)
      | Ok { name } ->
          if String.trim name = "" then
            Lwt.return (Response.bad_request "Name cannot be empty")
          else
            let* result = Db.Person.update ~id ~name in
            match result with
            | Error msg -> Lwt.return (Response.internal_error msg)
            | Ok None -> Lwt.return (Response.not_found "Person not found")
            | Ok (Some person) ->
                Lwt.return (Response.json_response (Model.Person.to_json person)))

let delete request =
  match Response.parse_int_param "id" request with
  | Error msg -> Lwt.return (Response.bad_request msg)
  | Ok id -> (
      let* result = Db.Person.delete ~id in
      match result with
      | Error msg -> Lwt.return (Response.internal_error msg)
      | Ok false -> Lwt.return (Response.not_found "Person not found")
      | Ok true -> Lwt.return (Dream.response ~status:`No_Content ""))
