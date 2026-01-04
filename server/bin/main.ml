open Connections_server
module Log = (val Logs.src_log (Logs.Src.create "main") : Logs.LOG)

let setup_logging log_file =
  let formatter =
    match log_file with
    | None ->
        Fmt_tty.setup_std_outputs ();
        Format.err_formatter
    | Some path ->
        let oc = open_out_gen [ Open_append; Open_creat ] 0o644 path in
        Format.formatter_of_out_channel oc
  in
  Logs.set_level (Some Logs.Info);
  Logs.set_reporter (Logs_fmt.reporter ~dst:formatter ());
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

let run db_path port no_scheduler log_file =
  setup_logging log_file;
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  (* Initialize database *)
  Db.Pool.init ~sw ~stdenv:env db_path;
  Db.Pool.apply_schema ();
  (* Set handler contexts for feed refresh, OPML import, URL metadata, article refresh, and person refresh *)
  Handlers.Rss_feed.set_context ~sw ~env;
  Handlers.Import.set_context ~sw ~env;
  Handlers.Metadata.set_context ~sw ~env;
  Handlers.Article.set_context ~sw ~env;
  Handlers.Person.set_context ~sw ~env;
  (* Start background jobs unless disabled *)
  if not no_scheduler then (
    Cron.Feed_sync.start ~sw ~env;
    Cron.Article_metadata_sync.start ~sw ~env);
  Log.info (fun m ->
      m "Starting server on port %d with database %s%s" port db_path
        (if no_scheduler then " (scheduler disabled)" else ""));
  (* Build and run the Tapak server *)
  let app = Router.build () in
  let address = `Tcp (Eio.Net.Ipaddr.V4.any, port) in
  let config = Piaf.Server.Config.create address in
  ignore (Tapak.run_with ~config ~env app)

(* CLI argument definitions *)
open Cmdliner

let db_path =
  let doc = "Path to the SQLite database file." in
  let env = Cmd.Env.info "DB_PATH" in
  Arg.(
    value & opt string "connections.db" & info [ "db" ] ~env ~docv:"PATH" ~doc)

let port =
  let doc = "Port to listen on." in
  let env = Cmd.Env.info "PORT" in
  Arg.(value & opt int 8080 & info [ "p"; "port" ] ~env ~docv:"PORT" ~doc)

let no_scheduler =
  let doc = "Disable the background RSS feed scheduler." in
  Arg.(value & flag & info [ "no-scheduler" ] ~doc)

let log_file =
  let doc = "Path to log file. If not specified, logs to stderr." in
  Arg.(value & opt (some string) None & info [ "log-file" ] ~docv:"PATH" ~doc)

let run_cmd =
  let doc = "Connections server for managing people and their RSS feeds" in
  let info = Cmd.info "connections-server" ~doc in
  Cmd.v info Term.(const run $ db_path $ port $ no_scheduler $ log_file)

let () = exit (Cmd.eval run_cmd)
