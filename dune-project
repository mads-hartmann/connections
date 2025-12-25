(lang dune 3.8)

(name connections-server)

(opam_file_location inside_opam_directory)

(generate_opam_files true)

(formatting (enabled_for ocaml))

(package
 (name connections-server)
 (synopsis "A simple web server for managing connections (people)")
 (depends
  (ocaml (>= 5.4.0))
  (dune (>= 3.0))
  tapak ; pinned from https://github.com/syaiful6/tapak.git
  (caqti (>= 2.0.0))
  (caqti-driver-sqlite3 (>= 2.0.0))
  (caqti-eio (>= 2.0.0))
  (yojson (>= 2.0.0))
  (ppx_yojson_conv (>= 0.15.0))
  (eio (>= 1.0))
  (eio_main (>= 1.0))
  (piaf (>= 0.2.0))
  (syndic (>= 1.7.0))
  (logs (>= 0.7.0))
  (fmt (>= 0.9.0))
  (ocamlformat (>= 0.28.1))
  (ocaml-lsp-server (>= 01.24.0))
  (alcotest (>= 1.7.0))))
