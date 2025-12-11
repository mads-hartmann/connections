(lang dune 3.8)

(name connections-server)

(opam_file_location inside_opam_directory)

(generate_opam_files true)

(formatting (enabled_for ocaml))

(package
 (name connections-server)
 (synopsis "A simple web server for managing connections (people)")
 (depends
  (ocaml (>= 4.14.0))
  (dune (>= 3.0))
  (dream (>= 1.0.0~alpha5))
  (caqti (>= 2.0.0))
  (caqti-driver-sqlite3 (>= 2.0.0))
  (caqti-lwt (>= 2.0.0))
  (yojson (>= 2.0.0))
  (ppx_yojson_conv (>= 0.15.0))
  (lwt (>= 5.6.0))
  (syndic (>= 1.7.0))
  (cohttp-lwt-unix (>= 5.0.0))
  (ocamlformat (>= 0.28.1))
  (ocaml-lsp-server (>= 01.24.0))))
