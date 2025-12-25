open Connections_server
module Log = (val Logs.src_log (Logs.Src.create "main") : Logs.LOG)

let setup_logging () =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level (Some Logs.Info);
  Logs.set_reporter (Logs_fmt.reporter ());
  (* Silence verbose Piaf/HTTP logging *)
  let noisy_prefixes = [ "piaf"; "httpun"; "h2"; "gluten"; "ssl" ] in
  List.iter
    (fun src ->
      let name = Logs.Src.name src in
      if
        List.exists
          (fun prefix -> String.starts_with ~prefix name)
          noisy_prefixes
      then Logs.Src.set_level src (Some Logs.Warning))
    (Logs.Src.list ())

let () =
  setup_logging ();
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let db_path =
    Sys.getenv_opt "DB_PATH" |> Option.value ~default:"connections.db"
  in
  let port =
    Sys.getenv_opt "PORT"
    |> Option.map int_of_string_opt
    |> Option.join |> Option.value ~default:8080
  in
  (* Initialize database *)
  Db.Pool.init ~sw ~stdenv:env db_path;
  Db.Pool.apply_schema ();
  (* Set handler contexts for feed refresh, OPML import, and URL metadata *)
  Handlers.Rss_feed.set_context ~sw ~env;
  Handlers.Import.set_context ~sw ~env;
  Handlers.Metadata.set_context ~sw ~env;
  (* Start background RSS feed scheduler *)
  Scheduler.start ~sw ~env;
  Log.info (fun m ->
      m "Starting server on port %d with database %s" port db_path);
  (* Build and run the Tapak server *)
  let app = Router.build () in
  let address = `Tcp (Eio.Net.Ipaddr.V4.any, port) in
  let config = Piaf.Server.Config.create address in
  ignore (Tapak.Server.run_with ~config ~env app)
