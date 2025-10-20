(lang dune 3.16)
(name melange-cloudflare)

(generate_opam_files true)

(source (github void/melange-cloudflare))
(license MIT)
(authors "Christopher Bothwell")
(maintainers "Christopher Bothwell")

(package
  (name melange-cloudflare)
  (synopsis "Melage bindings for Cloudflare Workers")
  (description "Type-safe OCaml/Reason bindings for Cloudflare Workers API, including KV, D1, R2, Durable Objects, and more")
  (depends 
    (ocaml (>=4.14))
    (dune (>= 3.16))
    (melange (>= 4.0))))
