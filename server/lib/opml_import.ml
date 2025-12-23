open Ppx_yojson_conv_lib.Yojson_conv.Primitives

(* Shared types for preview and confirm *)
type feed_info = { url : string; title : string option } [@@deriving yojson]

type person_info = {
  name : string;
  feeds : feed_info list;
  categories : string list;
}
[@@deriving yojson]

type import_error = { url : string; error : string } [@@deriving yojson]

type preview_response = {
  people : person_info list;
  errors : import_error list;
}
[@@deriving yojson]

type confirm_request = { people : person_info list } [@@deriving yojson]

type confirm_response = {
  created_people : int;
  created_feeds : int;
  created_categories : int;
}
[@@deriving yojson]

let preview_response_to_json response = yojson_of_preview_response response
let confirm_request_of_json json = confirm_request_of_yojson json
let confirm_response_to_json response = yojson_of_confirm_response response

(* Concurrency limit for fetching feeds *)
let max_concurrent_fetches = 5

(* Timeout for individual feed fetch in seconds *)
let fetch_timeout_seconds = 10.0

(* Fetch a single feed with timeout *)
let fetch_with_timeout ~sw ~env ~clock url =
  let result = ref (Error "Timeout") in
  let done_flag = ref false in
  Eio.Fiber.both
    (fun () ->
      if not !done_flag then (
        let r = Feed_fetcher.fetch_feed_metadata ~sw ~env url in
        if not !done_flag then (
          result := r;
          done_flag := true)))
    (fun () ->
      Eio.Time.sleep clock fetch_timeout_seconds;
      if not !done_flag then done_flag := true);
  !result

(* Process OPML entries: fetch metadata and group by author *)
let process_entries ~sw ~env (entries : Opml_parser.feed_entry list) :
    preview_response =
  let clock = Eio.Stdenv.clock env in
  let semaphore = Eio.Semaphore.make max_concurrent_fetches in
  (* Fetch all feeds with limited concurrency *)
  let fetch_one entry =
    Eio.Semaphore.acquire semaphore;
    let result =
      try fetch_with_timeout ~sw ~env ~clock entry.Opml_parser.url
      with exn -> Error (Printexc.to_string exn)
    in
    Eio.Semaphore.release semaphore;
    (entry, result)
  in
  (* Process entries in parallel with fiber list *)
  let results =
    Eio.Fiber.List.map
      (fun entry -> fetch_one entry)
      entries
  in
  (* Separate successes and errors *)
  let successes, errors =
    List.partition_map
      (fun (entry, result) ->
        match result with
        | Ok metadata -> Left (entry, metadata)
        | Error msg -> Right { url = entry.Opml_parser.url; error = msg })
      results
  in
  (* Group by author name, using feed title as fallback *)
  let by_author = Hashtbl.create 16 in
  List.iter
    (fun (entry, metadata) ->
      let author_name =
        match metadata.Feed_fetcher.author with
        | Some name -> name
        | None -> (
            match metadata.title with
            | Some t -> t
            | None -> (
                match entry.Opml_parser.title with
                | Some t -> t
                | None -> "Unknown"))
      in
      let feed =
        {
          url = entry.Opml_parser.url;
          title =
            (match entry.Opml_parser.title with
            | Some t -> Some t
            | None -> metadata.title);
        }
      in
      let existing =
        match Hashtbl.find_opt by_author author_name with
        | Some (feeds, cats) -> (feeds, cats)
        | None -> ([], [])
      in
      let feeds, cats = existing in
      let new_cats =
        List.fold_left
          (fun acc cat -> if List.mem cat acc then acc else cat :: acc)
          cats entry.Opml_parser.categories
      in
      Hashtbl.replace by_author author_name (feed :: feeds, new_cats))
    successes;
  (* Convert to list *)
  let people : person_info list =
    Hashtbl.fold
      (fun name (feeds, categories) acc ->
        ({ name; feeds = List.rev feeds; categories = List.rev categories }
          : person_info)
        :: acc)
      by_author []
  in
  (* Sort by name *)
  let people = List.sort (fun a b -> String.compare a.name b.name) people in
  ({ people; errors } : preview_response)

(* Parse OPML and generate preview *)
let preview ~sw ~env (opml_content : string) :
    (preview_response, string) result =
  match Opml_parser.parse opml_content with
  | Error msg -> Error msg
  | Ok parse_result ->
      if List.length parse_result.feeds = 0 then
        Error "No feeds found in OPML file"
      else
        let response = process_entries ~sw ~env parse_result.feeds in
        Ok response

(* Confirm import - create people, feeds, and categories *)
let confirm (request : confirm_request) : (confirm_response, string) result =
  let created_people = ref 0 in
  let created_feeds = ref 0 in
  let created_categories = ref 0 in
  let category_cache = Hashtbl.create 16 in
  (* Helper to get or create category *)
  let get_or_create_category name =
    match Hashtbl.find_opt category_cache name with
    | Some id -> Ok id
    | None -> (
        let result = Db.Category.get_or_create ~name in
        match result with
        | Error msg -> Error msg
        | Ok category ->
            Hashtbl.add category_cache name category.id;
            incr created_categories;
            Ok category.id)
  in
  (* Process each person *)
  let rec process_people = function
    | [] -> Ok ()
    | (person : person_info) :: rest -> (
        (* Create person *)
        let person_result = Db.Person.create ~name:person.name in
        match person_result with
        | Error msg -> Error msg
        | Ok created_person -> (
            incr created_people;
            (* Create feeds for this person *)
            let rec create_feeds = function
              | [] -> Ok ()
              | (feed : feed_info) :: rest -> (
                  let feed_result =
                    Db.Rss_feed.create ~person_id:created_person.id
                      ~url:feed.url ~title:feed.title
                  in
                  match feed_result with
                  | Error msg -> Error msg
                  | Ok _ ->
                      incr created_feeds;
                      create_feeds rest)
            in
            match create_feeds person.feeds with
            | Error msg -> Error msg
            | Ok () -> (
                (* Add categories to person *)
                let rec add_categories = function
                  | [] -> Ok ()
                  | cat_name :: rest -> (
                      match get_or_create_category cat_name with
                      | Error msg -> Error msg
                      | Ok cat_id -> (
                          match
                            Db.Category.add_to_person
                              ~person_id:created_person.id ~category_id:cat_id
                          with
                          | Error msg -> Error msg
                          | Ok () -> add_categories rest))
                in
                match add_categories person.categories with
                | Error msg -> Error msg
                | Ok () -> process_people rest)))
  in
  match process_people request.people with
  | Error msg -> Error msg
  | Ok () ->
      Ok
        {
          created_people = !created_people;
          created_feeds = !created_feeds;
          created_categories = !created_categories;
        }
