(* Tests for Person model and DB *)

open Connections_server
open Test_helpers

(* ============================================
   JSON Serialization Tests
   ============================================ *)

let test_person_to_json () =
  let person =
    Model.Person.create ~id:1 ~name:"Alice" ~photo:None ~tags:[] ~metadata:[]
  in
  let json = Model.Person.to_json person in
  match json with
  | `Assoc fields ->
      Alcotest.(check bool) "has id field" true (List.mem_assoc "id" fields);
      Alcotest.(check bool) "has name field" true (List.mem_assoc "name" fields);
      Alcotest.(check bool) "has tags field" true (List.mem_assoc "tags" fields);
      Alcotest.(check bool)
        "has metadata field" true
        (List.mem_assoc "metadata" fields)
  | _ -> Alcotest.fail "expected JSON object"

let test_person_to_json_with_metadata () =
  let metadata =
    [
      Model.Person_metadata.create ~id:1 ~person_id:1
        ~field_type:Model.Metadata_field_type.Email ~value:"alice@example.com";
    ]
  in
  let person =
    Model.Person.create ~id:1 ~name:"Alice" ~photo:None ~tags:[] ~metadata
  in
  let json = Model.Person.to_json person in
  match json with
  | `Assoc fields -> (
      match List.assoc_opt "metadata" fields with
      | Some (`List [ _ ]) -> ()
      | _ -> Alcotest.fail "expected metadata array with one item")
  | _ -> Alcotest.fail "expected JSON object"

let test_person_paginated_to_json () =
  let alice =
    Model.Person.create ~id:1 ~name:"Alice" ~photo:None ~tags:[] ~metadata:[]
  in
  let bob =
    Model.Person.create ~id:2 ~name:"Bob" ~photo:None ~tags:[] ~metadata:[]
  in
  let response =
    Model.Shared.Paginated.make ~data:[ alice; bob ] ~page:1 ~per_page:10
      ~total:2
  in
  let json = Model.Person.paginated_to_json response in
  match json with
  | `Assoc fields ->
      Alcotest.(check bool) "has data field" true (List.mem_assoc "data" fields);
      Alcotest.(check bool) "has page field" true (List.mem_assoc "page" fields);
      Alcotest.(check bool)
        "has total field" true
        (List.mem_assoc "total" fields)
  | _ -> Alcotest.fail "expected JSON object"

let json_suite =
  [
    Alcotest.test_case "Person.to_json" `Quick test_person_to_json;
    Alcotest.test_case "Person.to_json with metadata" `Quick
      test_person_to_json_with_metadata;
    Alcotest.test_case "Person.paginated_to_json" `Quick
      test_person_paginated_to_json;
  ]

(* ============================================
   Database Tests
   ============================================ *)

let caqti_err err = Format.asprintf "%a" Caqti_error.pp err

let test_db_person_create () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let result = Db.Person.create ~name:"Test Person" () in
  match result with
  | Error err -> Alcotest.fail ("create failed: " ^ caqti_err err)
  | Ok person ->
      Alcotest.(check string)
        "name matches" "Test Person" (Model.Person.name person);
      Alcotest.(check bool) "id is positive" true (Model.Person.id person > 0)

let test_db_person_get () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let create_result = Db.Person.create ~name:"Get Test" () in
  match create_result with
  | Error err -> Alcotest.fail ("create failed: " ^ caqti_err err)
  | Ok created -> (
      let get_result = Db.Person.get ~id:(Model.Person.id created) in
      match get_result with
      | Error err -> Alcotest.fail ("get failed: " ^ caqti_err err)
      | Ok None -> Alcotest.fail "person not found"
      | Ok (Some person) ->
          Alcotest.(check int)
            "id matches" (Model.Person.id created) (Model.Person.id person);
          Alcotest.(check string)
            "name matches" "Get Test" (Model.Person.name person))

let test_db_person_list () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let _ = Db.Person.create ~name:"Alice" () in
  let _ = Db.Person.create ~name:"Bob" () in
  let _ = Db.Person.create ~name:"Charlie" () in
  let result = Db.Person.list ~page:1 ~per_page:10 () in
  match result with
  | Error err -> Alcotest.fail ("list failed: " ^ caqti_err err)
  | Ok paginated ->
      Alcotest.(check int) "total is 3" 3 paginated.total;
      Alcotest.(check int) "data length is 3" 3 (List.length paginated.data)

let test_db_person_update () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let create_result = Db.Person.create ~name:"Original Name" () in
  match create_result with
  | Error err -> Alcotest.fail ("create failed: " ^ caqti_err err)
  | Ok created -> (
      let update_result =
        Db.Person.update ~id:(Model.Person.id created) ~name:"Updated Name"
          ~photo:None
      in
      match update_result with
      | Error err -> Alcotest.fail ("update failed: " ^ caqti_err err)
      | Ok None -> Alcotest.fail "person not found for update"
      | Ok (Some updated) ->
          Alcotest.(check string)
            "name updated" "Updated Name"
            (Model.Person.name updated))

let test_db_person_delete () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let create_result = Db.Person.create ~name:"To Delete" () in
  match create_result with
  | Error err -> Alcotest.fail ("create failed: " ^ caqti_err err)
  | Ok created -> (
      let created_id = Model.Person.id created in
      let delete_result = Db.Person.delete ~id:created_id in
      match delete_result with
      | Error err -> Alcotest.fail ("delete failed: " ^ caqti_err err)
      | Ok false -> Alcotest.fail "delete returned false"
      | Ok true -> (
          let get_result = Db.Person.get ~id:created_id in
          match get_result with
          | Error err ->
              Alcotest.fail ("get after delete failed: " ^ caqti_err err)
          | Ok None -> ()
          | Ok (Some _) -> Alcotest.fail "person still exists after delete"))

let db_suite =
  [
    Alcotest.test_case "create person" `Quick test_db_person_create;
    Alcotest.test_case "get person" `Quick test_db_person_get;
    Alcotest.test_case "list persons" `Quick test_db_person_list;
    Alcotest.test_case "update person" `Quick test_db_person_update;
    Alcotest.test_case "delete person" `Quick test_db_person_delete;
  ]

(* Handler tests are stubbed - Tapak doesn't have Dream's request mocking *)
let handler_suite = []
