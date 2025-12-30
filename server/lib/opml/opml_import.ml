open Ppx_yojson_conv_lib.Yojson_conv.Primitives

(* Shared types for preview and confirm *)
type feed_info = { url : string; title : string option } [@@deriving yojson]

type person_info = {
  name : string;
  feeds : feed_info list;
  tags : string list;
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
  created_tags : int;
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
      if not !done_flag then
        let r = Feed_fetcher.fetch_feed_metadata ~sw ~env url in
        if not !done_flag then (
          result := r;
          done_flag := true))
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
  let results = Eio.Fiber.List.map (fun entry -> fetch_one entry) entries in
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
        | Some (feeds, tags) -> (feeds, tags)
        | None -> ([], [])
      in
      let feeds, tags = existing in
      let new_tags =
        List.fold_left
          (fun acc tag -> if List.mem tag acc then acc else tag :: acc)
          tags entry.Opml_parser.tags
      in
      Hashtbl.replace by_author author_name (feed :: feeds, new_tags))
    successes;
  (* Convert to list *)
  let people : person_info list =
    Hashtbl.fold
      (fun name (feeds, tags) acc ->
        ({ name; feeds = List.rev feeds; tags = List.rev tags } : person_info)
        :: acc)
      by_author []
  in
  (* Sort by name *)
  let people = List.sort (fun a b -> String.compare a.name b.name) people in
  ({ people; errors } : preview_response)

(* Parse OPML and generate preview *)
let preview ~sw ~env (opml_content : string) : (preview_response, string) result
    =
  match Opml_parser.parse opml_content with
  | Error msg -> Error msg
  | Ok parse_result ->
      if List.length parse_result.feeds = 0 then
        Error "No feeds found in OPML file"
      else
        let response = process_entries ~sw ~env parse_result.feeds in
        Ok response

let caqti_err err = Format.asprintf "%a" Caqti_error.pp err

(* Confirm import - create people, feeds, and tags *)
let confirm (request : confirm_request) : (confirm_response, string) result =
  let created_people = ref 0 in
  let created_feeds = ref 0 in
  let created_tags = ref 0 in
  let tag_cache = Hashtbl.create 16 in
  (* Helper to get or create tag *)
  let get_or_create_tag name =
    match Hashtbl.find_opt tag_cache name with
    | Some id -> Ok id
    | None -> (
        let result = Db.Tag.get_or_create ~name in
        match result with
        | Error err -> Error (caqti_err err)
        | Ok tag ->
            let tag_id = Model.Tag.id tag in
            Hashtbl.add tag_cache name tag_id;
            incr created_tags;
            Ok tag_id)
  in
  (* Process each person *)
  let rec process_people = function
    | [] -> Ok ()
    | (person : person_info) :: rest -> (
        (* Create person *)
        let person_result = Db.Person.create ~name:person.name in
        match person_result with
        | Error err -> Error (caqti_err err)
        | Ok created_person -> (
            let created_person_id = Model.Person.id created_person in
            incr created_people;
            (* Create feeds for this person *)
            let rec create_feeds = function
              | [] -> Ok ()
              | (feed : feed_info) :: rest -> (
                  let feed_result =
                    Db.Rss_feed.create ~person_id:created_person_id
                      ~url:feed.url ~title:feed.title
                  in
                  match feed_result with
                  | Error err -> Error (caqti_err err)
                  | Ok _ ->
                      incr created_feeds;
                      create_feeds rest)
            in
            match create_feeds person.feeds with
            | Error msg -> Error msg
            | Ok () -> (
                (* Add tags to person *)
                let rec add_tags = function
                  | [] -> Ok ()
                  | tag_name :: rest -> (
                      match get_or_create_tag tag_name with
                      | Error msg -> Error msg
                      | Ok tag_id -> (
                          match
                            Db.Tag.add_to_person ~person_id:created_person_id
                              ~tag_id
                          with
                          | Error err -> Error (caqti_err err)
                          | Ok () -> add_tags rest))
                in
                match add_tags person.tags with
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
          created_tags = !created_tags;
        }
