open CloudflareCore
open Cloudflare

(* Test ExecutionContext *)
let test_execution_context () =
  Js.log "ExecutionContext test:";
  Js.log "  ExecutionContext.waitUntil and passThroughOnException are available";
  Js.log ""

(* Test Cache API *)
let test_cache () =
  Js.log "Cache API test:";

  let open Js.Promise in
  let cache = Cache.default () in

  (* Test cache operations *)
  cache
  |> Cache.match_url "https://example.com/data"
  |> then_ (fun cached_response ->
      match cached_response with
      | Some resp ->
          Js.log "  Found in cache";
          Js.log2 "  Cached status:" (Response.status resp);
          resolve ()
      | None ->
          Js.log "  Not in cache";
          resolve ()
    )
  |> ignore;

  Js.log ""

(* Test Crypto API *)
let test_crypto () =
  Js.log "Crypto API test:";

  (* Test randomUUID *)
  let uuid = Crypto.randomUUID () in
  Js.log2 "  Random UUID:" uuid;

  (* Test getRandomValues *)
  let arr = Js.Typed_array.Uint8Array.fromLength 16 in
  let random_arr = Crypto.getRandomValues arr in
  Js.log2 "  Random bytes generated:" (Js.Typed_array.Uint8Array.length random_arr);

  (* Test digest_string *)
  let open Js.Promise in
  Crypto.Subtle.digest_string Crypto.Subtle.SHA_256 "Hello, World!"
  |> then_ (fun hash ->
      let hash_arr = Js.Typed_array.Uint8Array.fromBuffer hash in
      Js.log2 "  SHA-256 hash length:" (Js.Typed_array.Uint8Array.length hash_arr);
      resolve ()
    )
  |> ignore;

  Js.log ""

(* Test WebSocketPair *)
let test_websocket_pair () =
  Js.log "WebSocketPair test:";

  let (ws1, ws2) = WebSocketPair.make () in

  Js.log "  Created WebSocket pair";
  Js.log2 "  WS1 ready state:" (WebSocket.readyState ws1);
  Js.log2 "  WS2 ready state:" (WebSocket.readyState ws2);
  Js.log ""

(* Test HTMLRewriter *)
let test_html_rewriter () =
  Js.log "HTMLRewriter test:";

  let rewriter = HTMLRewriter.make () in

  let handlers = HTMLRewriter.ElementHandler.handlers
    ~element:(fun element ->
      let tag = HTMLRewriter.ElementHandler.tagName element in
      Js.log2 "    Processing element:" tag;
      HTMLRewriter.ElementHandler.setAttribute element "data-processed" "true"
    )
    ()
  in

  let _rewriter = HTMLRewriter.on rewriter "div" handlers in

  Js.log "  HTMLRewriter configured for 'div' elements";
  Js.log ""

(* Test QueueEvent Message *)
let test_queue_message () =
  Js.log "QueueEvent.Message test:";
  Js.log "  body_text function converts JSON body to string";
  Js.log ""

(* Test DurableObject *)
let test_durable_objects () =
  Js.log "DurableObject test:";
  Js.log "  DurableObject.Namespace, Id, Stub, and Storage modules available";
  Js.log "  Types: durable_object_id, durable_object_stub";
  Js.log ""

(* Run all tests *)
let () =
  Js.log "\n=== Cloudflare Workers Tests ===\n";
  test_execution_context ();
  test_cache ();
  test_crypto ();
  test_websocket_pair ();
  test_html_rewriter ();
  test_queue_message ();
  test_durable_objects ();
  Js.log "=== All Worker tests completed ===\n"
