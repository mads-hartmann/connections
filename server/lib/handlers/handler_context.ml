(* Store sw and env for HTTP requests - set by main *)
let sw_ref : Eio.Switch.t option ref = ref None
let env_ref : Eio_unix.Stdenv.base option ref = ref None

let set_context ~sw ~env =
  sw_ref := Some sw;
  env_ref := Some env

let get_context () =
  match (!sw_ref, !env_ref) with
  | Some sw, Some env -> (sw, env)
  | _ -> failwith "Handler context not initialized"
