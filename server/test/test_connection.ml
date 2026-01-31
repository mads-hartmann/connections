(* Tests for Connection model and DB *)

open Connections_server
open Test_helpers

(* ============================================
   JSON Serialization Tests
   ============================================ *)

let test_connection_to_json () =
  let connection =
    Model.Connection.create ~id:1 ~name:"Alice" ~photo:None ~tags:[] ~metadata:[]
  in
  let json = Model.Connection.to_json connection in
  match json with
  | `Assoc fields ->
      Alcotest.(check bool) "has id field" true (List.mem_assoc "id" fields);
      Alcotest.(check bool) "has name field" true (List.mem_assoc "name" fields);
      Alcotest.(check bool) "has tags field" true (List.mem_assoc "tags" fields);
      Alcotest.(check bool)
        "has metadata field" true
        (List.mem_assoc "metadata" fields)
  | _ -> Alcotest.fail "expected JSON object"

let test_connection_to_json_with_metadata () =
  let metadata =
    [
      Model.Connection_metadata.create ~id:1 ~connection_id:1
        ~field_type:Model.Metadata_field_type.Email ~value:"alice@example.com";
    ]
  in
  let connection =
    Model.Connection.create ~id:1 ~name:"Alice" ~photo:None ~tags:[] ~metadata
  in
  let json = Model.Connection.to_json connection in
  match json with
  | `Assoc fields -> (
      match List.assoc_opt "metadata" fields with
      | Some (`List [ _ ]) -> ()
      | _ -> Alcotest.fail "expected metadata array with one item")
  | _ -> Alcotest.fail "expected JSON object"

let test_connection_paginated_to_json () =
  let alice =
    Model.Connection.create ~id:1 ~name:"Alice" ~photo:None ~tags:[] ~metadata:[]
  in
  let bob =
    Model.Connection.create ~id:2 ~name:"Bob" ~photo:None ~tags:[] ~metadata:[]
  in
  let response =
    Model.Shared.Paginated.make ~data:[ alice; bob ] ~page:1 ~per_page:10
      ~total:2
  in
  let json = Model.Connection.paginated_to_json response in
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
    Alcotest.test_case "Connection.to_json" `Quick test_connection_to_json;
    Alcotest.test_case "Connection.to_json with metadata" `Quick
      test_connection_to_json_with_metadata;
    Alcotest.test_case "Connection.paginated_to_json" `Quick
      test_connection_paginated_to_json;
  ]

(* ============================================
   Database Tests
   ============================================ *)

let caqti_err err = Format.asprintf "%a" Caqti_error.pp err

let test_db_connection_create () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let result = Db.Connection.create ~name:"Test Connection" () in
  match result with
  | Error err -> Alcotest.fail ("create failed: " ^ caqti_err err)
  | Ok connection ->
      Alcotest.(check string)
        "name matches" "Test Connection" (Model.Connection.name connection);
      Alcotest.(check bool) "id is positive" true (Model.Connection.id connection > 0)

let test_db_connection_get () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let create_result = Db.Connection.create ~name:"Get Test" () in
  match create_result with
  | Error err -> Alcotest.fail ("create failed: " ^ caqti_err err)
  | Ok created -> (
      let get_result = Db.Connection.get ~id:(Model.Connection.id created) in
      match get_result with
      | Error err -> Alcotest.fail ("get failed: " ^ caqti_err err)
      | Ok None -> Alcotest.fail "connection not found"
      | Ok (Some connection) ->
          Alcotest.(check int)
            "id matches" (Model.Connection.id created) (Model.Connection.id connection);
          Alcotest.(check string)
            "name matches" "Get Test" (Model.Connection.name connection))

let test_db_connection_list () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let _ = Db.Connection.create ~name:"Alice" () in
  let _ = Db.Connection.create ~name:"Bob" () in
  let _ = Db.Connection.create ~name:"Charlie" () in
  let result = Db.Connection.list ~page:1 ~per_page:10 () in
  match result with
  | Error err -> Alcotest.fail ("list failed: " ^ caqti_err err)
  | Ok paginated ->
      Alcotest.(check int) "total is 3" 3 paginated.total;
      Alcotest.(check int) "data length is 3" 3 (List.length paginated.data)

let test_db_connection_update () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let create_result = Db.Connection.create ~name:"Original Name" () in
  match create_result with
  | Error err -> Alcotest.fail ("create failed: " ^ caqti_err err)
  | Ok created -> (
      let update_result =
        Db.Connection.update ~id:(Model.Connection.id created) ~name:"Updated Name"
          ~photo:None
      in
      match update_result with
      | Error err -> Alcotest.fail ("update failed: " ^ caqti_err err)
      | Ok None -> Alcotest.fail "connection not found for update"
      | Ok (Some updated) ->
          Alcotest.(check string)
            "name updated" "Updated Name"
            (Model.Connection.name updated))

let test_db_connection_delete () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let create_result = Db.Connection.create ~name:"To Delete" () in
  match create_result with
  | Error err -> Alcotest.fail ("create failed: " ^ caqti_err err)
  | Ok created -> (
      let created_id = Model.Connection.id created in
      let delete_result = Db.Connection.delete ~id:created_id in
      match delete_result with
      | Error err -> Alcotest.fail ("delete failed: " ^ caqti_err err)
      | Ok false -> Alcotest.fail "delete returned false"
      | Ok true -> (
          let get_result = Db.Connection.get ~id:created_id in
          match get_result with
          | Error err ->
              Alcotest.fail ("get after delete failed: " ^ caqti_err err)
          | Ok None -> ()
          | Ok (Some _) -> Alcotest.fail "connection still exists after delete"))

let test_db_metadata_create_idempotent () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let connection = Db.Connection.create ~name:"Test Connection" () |> Result.get_ok in
  let connection_id = Model.Connection.id connection in
  let field_type_id = Model.Metadata_field_type.id Model.Metadata_field_type.Email in
  let value = "test@example.com" in
  (* First creation *)
  let first = Db.Connection_metadata.create ~connection_id ~field_type_id ~value in
  match first with
  | Error _ -> Alcotest.fail "first create failed"
  | Ok first_metadata ->
      (* Second creation with same values should return existing *)
      let second = Db.Connection_metadata.create ~connection_id ~field_type_id ~value in
      match second with
      | Error _ -> Alcotest.fail "second create failed"
      | Ok second_metadata ->
          Alcotest.(check int)
            "same id returned"
            (Model.Connection_metadata.id first_metadata)
            (Model.Connection_metadata.id second_metadata)

let test_db_metadata_create_idempotent_case_insensitive () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let connection = Db.Connection.create ~name:"Test Connection" () |> Result.get_ok in
  let connection_id = Model.Connection.id connection in
  let field_type_id = Model.Metadata_field_type.id Model.Metadata_field_type.Email in
  (* First creation with lowercase *)
  let first = Db.Connection_metadata.create ~connection_id ~field_type_id ~value:"test@example.com" in
  match first with
  | Error _ -> Alcotest.fail "first create failed"
  | Ok first_metadata ->
      (* Second creation with different case should return existing *)
      let second = Db.Connection_metadata.create ~connection_id ~field_type_id ~value:"TEST@EXAMPLE.COM" in
      match second with
      | Error _ -> Alcotest.fail "second create failed"
      | Ok second_metadata ->
          Alcotest.(check int)
            "same id returned for different case"
            (Model.Connection_metadata.id first_metadata)
            (Model.Connection_metadata.id second_metadata)

let test_db_metadata_create_idempotent_trimmed () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let connection = Db.Connection.create ~name:"Test Connection" () |> Result.get_ok in
  let connection_id = Model.Connection.id connection in
  let field_type_id = Model.Metadata_field_type.id Model.Metadata_field_type.Email in
  (* First creation without whitespace *)
  let first = Db.Connection_metadata.create ~connection_id ~field_type_id ~value:"test@example.com" in
  match first with
  | Error _ -> Alcotest.fail "first create failed"
  | Ok first_metadata ->
      (* Second creation with whitespace should return existing *)
      let second = Db.Connection_metadata.create ~connection_id ~field_type_id ~value:"  test@example.com  " in
      match second with
      | Error _ -> Alcotest.fail "second create failed"
      | Ok second_metadata ->
          Alcotest.(check int)
            "same id returned for whitespace-padded value"
            (Model.Connection_metadata.id first_metadata)
            (Model.Connection_metadata.id second_metadata)

let test_db_metadata_create_different_values () =
  with_eio @@ fun ~sw ~env ->
  setup_test_db ~sw ~stdenv:env;
  let connection = Db.Connection.create ~name:"Test Connection" () |> Result.get_ok in
  let connection_id = Model.Connection.id connection in
  let field_type_id = Model.Metadata_field_type.id Model.Metadata_field_type.Email in
  (* First creation *)
  let first = Db.Connection_metadata.create ~connection_id ~field_type_id ~value:"first@example.com" in
  match first with
  | Error _ -> Alcotest.fail "first create failed"
  | Ok first_metadata ->
      (* Second creation with different value should create new *)
      let second = Db.Connection_metadata.create ~connection_id ~field_type_id ~value:"second@example.com" in
      match second with
      | Error _ -> Alcotest.fail "second create failed"
      | Ok second_metadata ->
          Alcotest.(check bool)
            "different ids for different values"
            true
            (Model.Connection_metadata.id first_metadata <> Model.Connection_metadata.id second_metadata)

let db_suite =
  [
    Alcotest.test_case "create connection" `Quick test_db_connection_create;
    Alcotest.test_case "get connection" `Quick test_db_connection_get;
    Alcotest.test_case "list connections" `Quick test_db_connection_list;
    Alcotest.test_case "update connection" `Quick test_db_connection_update;
    Alcotest.test_case "delete connection" `Quick test_db_connection_delete;
    Alcotest.test_case "metadata create idempotent" `Quick
      test_db_metadata_create_idempotent;
    Alcotest.test_case "metadata create idempotent case-insensitive" `Quick
      test_db_metadata_create_idempotent_case_insensitive;
    Alcotest.test_case "metadata create idempotent trimmed" `Quick
      test_db_metadata_create_idempotent_trimmed;
    Alcotest.test_case "metadata create different values" `Quick
      test_db_metadata_create_different_values;
  ]

(* Handler tests are stubbed - Tapak doesn't have Dream's request mocking *)
let handler_suite = []
