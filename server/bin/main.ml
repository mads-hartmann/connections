open Connections_server

module Log = (val Logs.src_log (Logs.Src.create "main") : Logs.LOG)

let setup_logging () =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level (Some Logs.Info);
  Logs.set_reporter (Logs_fmt.reporter ())

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
  Db.Person.init_table ();
  Db.Rss_feed.init_table ();
  Db.Article.init_table ();
  Db.Category.init_table ();
  (* Set handler contexts for feed refresh and OPML import *)
  Handlers.Rss_feed.set_context ~sw ~env;
  Handlers.Import.set_context ~sw ~env;
  (* Start background RSS feed scheduler *)
  Scheduler.start ~sw ~env;
  Log.info (fun m -> m "Starting server on port %d with database %s" port db_path);
  (* Build and run the Tapak server *)
  let app = Router.build () in
  let address = `Tcp (Eio.Net.Ipaddr.V4.any, port) in
  let config = Piaf.Server.Config.create address in
  ignore (Tapak.Server.run_with ~config ~env app)
