open Connections_server

let () =
  Lwt_main.run
    begin
      let open Lwt.Syntax in
      let db_path =
        Sys.getenv_opt "DB_PATH" |> Option.value ~default:"connections.db"
      in
      let port =
        Sys.getenv_opt "PORT"
        |> Option.map int_of_string_opt
        |> Option.join |> Option.value ~default:8080
      in
      let* () = Db.init db_path in
      let* () = Db.Person.init_table () in
      Dream.log "Starting server on port %d with database %s" port db_path;
      Dream.serve ~port @@ Dream.logger @@ Router.build ()
    end
