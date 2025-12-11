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
      let* () = Db.Pool.init db_path in
      let* () = Db.Person.init_table () in
      let* () = Db.Rss_feed.init_table () in
      let* () = Db.Article.init_table () in
      (* Start background RSS feed scheduler *)
      Scheduler.start ();
      Dream.log "Starting server on port %d with database %s" port db_path;
      Dream.serve ~interface:"0.0.0.0" ~port @@ Dream.logger @@ Router.build ()
    end
