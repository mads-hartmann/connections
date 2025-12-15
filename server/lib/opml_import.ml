open Lwt.Syntax
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
let fetch_with_timeout url =
  let timeout =
    let* () = Lwt_unix.sleep fetch_timeout_seconds in
    Lwt.return_error "Timeout"
  in
  let fetch = Feed_fetcher.fetch_feed_metadata url in
  Lwt.pick [ timeout; fetch ]

(* Process OPML entries: fetch metadata and group by author *)
let process_entries (entries : Opml_parser.feed_entry list) :
    preview_response Lwt.t =
  (* Fetch all feeds with limited concurrency *)
  let semaphore = Lwt_mutex.create () in
  let active_count = ref 0 in
  let fetch_one entry =
    (* Wait for slot *)
    let rec wait_for_slot () =
      let* () = Lwt_mutex.lock semaphore in
      if !active_count >= max_concurrent_fetches then (
        Lwt_mutex.unlock semaphore;
        let* () = Lwt_unix.sleep 0.1 in
        wait_for_slot ())
      else (
        incr active_count;
        Lwt_mutex.unlock semaphore;
        Lwt.return_unit)
    in
    let* () = wait_for_slot () in
    let* result = fetch_with_timeout entry.Opml_parser.url in
    let* () = Lwt_mutex.lock semaphore in
    decr active_count;
    Lwt_mutex.unlock semaphore;
    Lwt.return (entry, result)
  in
  let* results = Lwt_list.map_p fetch_one entries in
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
  Lwt.return ({ people; errors } : preview_response)

(* Parse OPML and generate preview *)
let preview (opml_content : string) : (preview_response, string) result Lwt.t =
  match Opml_parser.parse opml_content with
  | Error msg -> Lwt.return_error msg
  | Ok parse_result ->
      if List.length parse_result.feeds = 0 then
        Lwt.return_error "No feeds found in OPML file"
      else
        let* response = process_entries parse_result.feeds in
        Lwt.return_ok response

(* Confirm import - create people, feeds, and categories *)
let confirm (request : confirm_request) :
    (confirm_response, string) result Lwt.t =
  let created_people = ref 0 in
  let created_feeds = ref 0 in
  let created_categories = ref 0 in
  let category_cache = Hashtbl.create 16 in
  (* Helper to get or create category *)
  let get_or_create_category name =
    match Hashtbl.find_opt category_cache name with
    | Some id -> Lwt.return_ok id
    | None -> (
        let* result = Db.Category.get_or_create ~name in
        match result with
        | Error msg -> Lwt.return_error msg
        | Ok category ->
            Hashtbl.add category_cache name category.id;
            incr created_categories;
            Lwt.return_ok category.id)
  in
  (* Process each person *)
  let* results =
    Lwt_list.map_s
      (fun (person : person_info) ->
        (* Create person *)
        let* person_result = Db.Person.create ~name:person.name in
        match person_result with
        | Error msg -> Lwt.return_error msg
        | Ok created_person ->
            incr created_people;
            (* Create feeds for this person *)
            let* feed_results =
              Lwt_list.map_s
                (fun (feed : feed_info) ->
                  let* feed_result =
                    Db.Rss_feed.create ~person_id:created_person.id
                      ~url:feed.url ~title:feed.title
                  in
                  match feed_result with
                  | Error msg -> Lwt.return_error msg
                  | Ok _ ->
                      incr created_feeds;
                      Lwt.return_ok ())
                person.feeds
            in
            (* Check for feed errors *)
            let feed_errors =
              List.filter_map
                (function Error msg -> Some msg | Ok () -> None)
                feed_results
            in
            if List.length feed_errors > 0 then
              Lwt.return_error (String.concat "; " feed_errors)
            else
              (* Add categories to person *)
              let* cat_results =
                Lwt_list.map_s
                  (fun cat_name ->
                    let* cat_id_result = get_or_create_category cat_name in
                    match cat_id_result with
                    | Error msg -> Lwt.return_error msg
                    | Ok cat_id ->
                        Db.Category.add_to_person ~person_id:created_person.id
                          ~category_id:cat_id)
                  person.categories
              in
              let cat_errors =
                List.filter_map
                  (function Error msg -> Some msg | Ok () -> None)
                  cat_results
              in
              if List.length cat_errors > 0 then
                Lwt.return_error (String.concat "; " cat_errors)
              else Lwt.return_ok ())
      request.people
  in
  (* Check for any errors *)
  let errors =
    List.filter_map (function Error msg -> Some msg | Ok () -> None) results
  in
  if List.length errors > 0 then Lwt.return_error (String.concat "; " errors)
  else
    Lwt.return_ok
      {
        created_people = !created_people;
        created_feeds = !created_feeds;
        created_categories = !created_categories;
      }
