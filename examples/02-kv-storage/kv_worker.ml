(** KV Storage Example

    This example demonstrates:
    - Reading and writing to KV storage
    - Using metadata with KV entries
    - Setting expiration with TTL
    - Listing keys with pagination
    - Different value types (text, JSON, binary)
*)

open Cloudflare
open Workers

module Promise = struct 
  include Js.Promise

  let bind f x = then_ x f 
  let ( >>= ) = bind

  let map f promise = then_ (fun x -> resolve(f x)) promise 
  let ( >|= ) = map

  let return x = resolve x
  
  module Syntax = struct
    let ( let* ) = bind
    let ( let+ ) p f = map f p
  end
end

(* Our environment type with KV binding *)
type env = {
  cache : Kv.Namespace.t; [@mel.as "CACHE"]
} [@@deriving jsProperties]

module Utils = struct
  let generate_random_code () = String.init 12 (
    fun _ -> 65 + (Random.int 25) |> Char.chr
  )
end

module URLData = struct
  open Melange_json.Primitives

  type t = {
    full_url: string;
    created_at: float;
    clicks: int [@json.default 0];
  } [@@deriving json]


  let create_short_url data kv = 
    let code = Utils.generate_random_code () in 
    Kv.Namespace.put_json_with_options kv code (data |> to_json) {
      expiration = None; 
      expirationTtl = Some (20 * 24 * 3600); (* Expire in 30 days *)
      metadata = Some (Js.Json.object_ (Js.Dict.fromList [
        ("CreatedAt", Js.Json.number (Js.Date.now ()))
      ]));
    }

  let redirect kv code = 
    let of_json_string str = 
      try
        let json = Melange_json.of_string str in 
        Ok (of_json json)
      with 
      | Melange_json.Of_json_error err -> 
          Error (Melange_json.of_json_error_to_string err)
      | Melange_json.Of_string_error msg ->
          Error msg
    in 
    let open Promise in
    Kv.Namespace.get kv code 
    >>= (function 
      | Some value -> 
           match of_json_string value with 
            | Ok url_data -> begin Kv.Namespace.put_json kv code @@ to_json { 
                url_data with clicks = succ url_data.clicks
              } >>= (function _ -> return ()
            | Error -> return ()
      | None -> return ()
end

let handle_error message status = 
  let headers = Headers.of_list [
    ("Content-Type", "text/text; charset=utf-8");
  ] in
  let body = BodyInit.string message in
  let init = {
    Response.status = Some status;
    statusText = None;
    headers = Some headers
  } in
  Response.make ~body init

let handle_list_cache env =
  let open Js.Promise in
  Kv.Namespace.list env.cache
  |> then_ (fun result ->
      let json = Json_helpers.encode_list_result result in
      let body = BodyInit.string (Js.Json.stringify json) in
      let headers = Headers.of_list [
        ("Content-Type", "application/json; charset=utf-8");
      ] in
      let init = {
        Response.status = Some 200;
        statusText = None;
        headers = Some headers
      } in
      resolve (Response.make ~body init)
  )

(* Main request handler *)
let handle_request (request : Request.t) (env : env) (_ctx : ExecutionContext.t) =
  let open Js.Promise in

  let url = Request.url request in
  Js.log2 "KV Worker request:" url;

  (* Simple routing - just demonstrate listing for now *)
  if Js.String.includes ~search:"/cache" url then
    handle_list_cache env
  else
    (* Default response *)
    let body = BodyInit.string "KV Storage Worker - visit /cache to list keys" in
    let init = {
      Response.status = Some 200;
      statusText = None;
      headers = None
    } in
    resolve (Response.make ~body init)

(* Export handler *)
let default = Handler.make ~fetch:handle_request ()
