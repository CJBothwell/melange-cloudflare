(** Cloudflare Workers Runtime API.

    This module provides bindings to the Cloudflare Workers runtime environment,
    including the fetch event handler, environment variables, execution context,
    and various Workers-specific APIs.
*)

open Cloudflare

(** {1 Workers Environment} *)

module type ENV = sig
  type t
end

(** {1 Execution Context} *)

module ExecutionContext = struct
  type t

  external waitUntil : t -> 'a Js.Promise.t -> unit = "waitUntil" [@@mel.send]

  external passThroughOnException : t -> unit = "passThroughOnException" [@@mel.send]
end

(** {1 Fetch Event Handler} *)

module FetchEvent = struct
  type 'env handler = Request.t -> 'env -> ExecutionContext.t -> Response.t Js.Promise.t

  type 'env t

  external request : 'env t -> Request.t = "request" [@@mel.get]
  external env : 'env t -> 'env = "env" [@@mel.get]
  external respondWith : 'env t -> Response.t Js.Promise.t -> unit = "respondWith" [@@mel.send]

  (* FetchEvent extends ExecutionContext in Workers *)
  external asExecutionContext : 'env t -> ExecutionContext.t = "%identity"

  external addEventListener : string -> ('env t -> unit) -> unit = "addEventListener"

  (* TODO: DEPRECATED - This addEventListener pattern is deprecated.
     Use the modern Handler API instead:
       let default = Handler.make ~fetch:my_handler ()
     This legacy API may be removed in a future version. *)
  let on_fetch (handler : 'env handler) =
    addEventListener "fetch" (fun event ->
      let request = request event in
      let env_obj = env event in
      let ctx = asExecutionContext event in
      let response_promise = handler request env_obj ctx in
      respondWith event response_promise
    )
end

(** {1 Scheduled Event Handler} *)

module ScheduledEvent = struct
  type 'env t

  external scheduledTime : 'env t -> float = "scheduledTime" [@@mel.get]

  external cron : 'env t -> string = "cron" [@@mel.get]

  external env : 'env t -> 'env = "env" [@@mel.get]

  external asExecutionContext : 'env t -> ExecutionContext.t = "%identity"

  external addEventListener : string -> ('env t -> unit) -> unit = "addEventListener"

  type 'env handler = 'env t -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (* TODO: DEPRECATED - This addEventListener pattern is deprecated.
     Use the modern Handler API instead:
       let default = Handler.make ~scheduled:my_handler ()
     This legacy API may be removed in a future version. *)
  let on_scheduled (handler : 'env handler) =
    addEventListener "scheduled" (fun event ->
      let env_obj = env event in
      let ctx = asExecutionContext event in
      let promise = handler event env_obj ctx in
      ExecutionContext.waitUntil ctx promise
    )
end

(** {1 Queue Consumer} *)

module QueueEvent = struct
  module Message = struct
    type t

    external id : t -> string = "id" [@@mel.get]

    external timestamp : t -> float = "timestamp" [@@mel.get]

    external body : t -> Js.Json.t = "body" [@@mel.get]

    let body_text msg =
      (* Convert JSON body to string *)
      body msg |> Js.Json.stringify

    external retry : t -> unit = "retry" [@@mel.send]

    external ack : t -> unit = "ack" [@@mel.send]
  end

  module Batch = struct
    type t

    external queue : t -> string = "queue" [@@mel.get]

    external messages : t -> Message.t array = "messages" [@@mel.get]

    external retryAll : t -> unit = "retryAll" [@@mel.send]

    external ackAll : t -> unit = "ackAll" [@@mel.send]
  end

  type 'env t

  external batch : 'env t -> Batch.t = "batch" [@@mel.get]

  external env : 'env t -> 'env = "env" [@@mel.get]

  external asExecutionContext : 'env t -> ExecutionContext.t = "%identity"

  external addEventListener : string -> ('env t -> unit) -> unit = "addEventListener"

  type 'env handler = Batch.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (* TODO: DEPRECATED - This addEventListener pattern is deprecated.
     Use the modern Handler API instead:
       let default = Handler.make ~queue:my_handler ()
     This legacy API may be removed in a future version. *)
  let on_queue (handler : 'env handler) =
    addEventListener "queue" (fun event ->
      let batch = batch event in
      let env_obj = env event in
      let ctx = asExecutionContext event in
      let promise = handler batch env_obj ctx in
      ExecutionContext.waitUntil ctx promise
    )
end

(** {1 Email Event Handler} *)

module EmailEvent = struct
  module Message = struct
    type t

    external from : t -> string = "from" [@@mel.get]

    external to_ : t -> string = "to" [@@mel.get]

    external headers : t -> Headers.t = "headers" [@@mel.get]

    external raw : t -> readableStream = "raw" [@@mel.get]

    external rawSize : t -> int = "rawSize" [@@mel.get]

    external forward : t -> string -> unit Js.Promise.t = "forward" [@@mel.send]

    external setReject : t -> string -> unit = "setReject" [@@mel.send]
  end

  type 'env t

  external message : 'env t -> Message.t = "message" [@@mel.get]

  external env : 'env t -> 'env = "env" [@@mel.get]

  external asExecutionContext : 'env t -> ExecutionContext.t = "%identity"

  external addEventListener : string -> ('env t -> unit) -> unit = "addEventListener"

  type 'env handler = Message.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (* TODO: DEPRECATED - This addEventListener pattern is deprecated.
     Use the modern Handler API instead:
       let default = Handler.make ~email:my_handler ()
     This legacy API may be removed in a future version. *)
  let on_email (handler : 'env handler) =
    addEventListener "email" (fun event ->
      let message = message event in
      let env_obj = env event in
      let ctx = asExecutionContext event in
      let promise = handler message env_obj ctx in
      ExecutionContext.waitUntil ctx promise
    )
end

(** {1 Cache API} *)

module Cache = struct
  type t

  external default : unit -> t = "default" [@@mel.scope "caches"]

  external open_ : string -> t Js.Promise.t = "open" [@@mel.scope "caches"]

  external match_ : t -> Request.t -> Response.t option Js.Promise.t = "match" [@@mel.send]

  let match_url cache url =
    let req = Request.make url in
    match_ cache req

  external put : t -> Request.t -> Response.t -> unit Js.Promise.t = "put" [@@mel.send]

  let put_url cache url response =
    let req = Request.make url in
    put cache req response

  external delete : t -> Request.t -> bool Js.Promise.t = "delete" [@@mel.send]

  let delete_url cache url =
    let req = Request.make url in
    delete cache req
end

(** {1 Crypto API} *)

module Crypto = struct
  external getRandomValues : Js.Typed_array.Uint8Array.t -> Js.Typed_array.Uint8Array.t =
    "getRandomValues" [@@mel.scope "crypto"]

  external randomUUID : unit -> string = "randomUUID" [@@mel.scope "crypto"]

  module Subtle = struct
    type t

    type hash_algorithm =
      | SHA_1
      | SHA_256
      | SHA_384
      | SHA_512

    let hash_algorithm_to_string = function
      | SHA_1 -> "SHA-1"
      | SHA_256 -> "SHA-256"
      | SHA_384 -> "SHA-384"
      | SHA_512 -> "SHA-512"

    external digest_arrayBuffer :
      string -> Fetch.arrayBuffer -> Fetch.arrayBuffer Js.Promise.t =
      "digest" [@@mel.scope ("crypto", "subtle")]

    external digest_uint8Array :
      string -> Js.Typed_array.Uint8Array.t -> Fetch.arrayBuffer Js.Promise.t =
      "digest" [@@mel.scope ("crypto", "subtle")]

    let digest alg data =
      digest_arrayBuffer (hash_algorithm_to_string alg) data

    let digest_string alg data =
      (* Convert string to Uint8Array using TextEncoder *)
      let encoder = Cloudflare.TextEncoder.make () in
      let uint8_array = Cloudflare.TextEncoder.encode encoder data in
      digest_uint8Array (hash_algorithm_to_string alg) uint8_array
  end

  external subtle : unit -> Subtle.t = "subtle" [@@mel.scope "crypto"]
end

(** {1 HTMLRewriter} *)

module HTMLRewriter = struct
  type t

  module ElementHandler = struct
    type element

    external tagName : element -> string = "tagName" [@@mel.get]

    external getAttribute : element -> string -> string option = "getAttribute" [@@mel.send]

    external setAttribute : element -> string -> string -> unit = "setAttribute" [@@mel.send]

    external removeAttribute : element -> string -> unit = "removeAttribute" [@@mel.send]

    external hasAttribute : element -> string -> bool = "hasAttribute" [@@mel.send]

    external before : element -> string -> unit = "before" [@@mel.send]

    external after : element -> string -> unit = "after" [@@mel.send]

    external prepend : element -> string -> unit = "prepend" [@@mel.send]

    external append : element -> string -> unit = "append" [@@mel.send]

    external replace : element -> string -> unit = "replace" [@@mel.send]

    external remove : element -> unit = "remove" [@@mel.send]

    external removeAndKeepContent : element -> unit = "removeAndKeepContent" [@@mel.send]

    type handlers = {
      element : (element -> unit) option; [@mel.optional]
      comments : (string -> unit) option; [@mel.optional]
      text : (string -> unit) option; [@mel.optional]
    }
    [@@deriving jsProperties]
  end

  external make : unit -> t = "HTMLRewriter" [@@mel.new]

  external on_ : t -> string -> ElementHandler.handlers -> t = "on" [@@mel.send]

  external onDocument_ : t -> ElementHandler.handlers -> t = "onDocument" [@@mel.send]

  let on t selector handlers =
    let js_handlers = ElementHandler.handlers
      ?element:handlers.ElementHandler.element
      ?comments:handlers.ElementHandler.comments
      ?text:handlers.ElementHandler.text
      ()
    in
    on_ t selector js_handlers

  let onDocument t handlers =
    let js_handlers = ElementHandler.handlers
      ?element:handlers.ElementHandler.element
      ?comments:handlers.ElementHandler.comments
      ?text:handlers.ElementHandler.text
      ()
    in
    onDocument_ t js_handlers

  external transform : t -> Response.t -> Response.t = "transform" [@@mel.send]
end

(** {1 WebSocket} *)

module WebSocket = struct
  type t

  type ready_state =
    | Connecting
    | Open
    | Closing
    | Closed

  let ready_state_of_int = function
    | 0 -> Connecting
    | 1 -> Open
    | 2 -> Closing
    | 3 -> Closed
    | _ -> failwith "Invalid WebSocket ready state"

  external readyState_internal : t -> int = "readyState" [@@mel.get]

  let readyState ws =
    ready_state_of_int (readyState_internal ws)

  external url : t -> string = "url" [@@mel.get]

  external send : t -> string -> unit = "send" [@@mel.send]

  external send_buffer : t -> Fetch.arrayBuffer -> unit = "send" [@@mel.send]

  external close : t -> unit = "close" [@@mel.send]

  external close_with_code : t -> int -> string option -> unit = "close" [@@mel.send]

  external accept : t -> unit = "accept" [@@mel.send]

  module Events = struct
    external onMessage : t -> (string -> unit) -> unit = "onmessage" [@@mel.set]

    external onClose : t -> (int -> string -> bool -> unit) -> unit = "onclose" [@@mel.set]

    external onError : t -> (Js.Exn.t -> unit) -> unit = "onerror" [@@mel.set]

    external onOpen : t -> (unit -> unit) -> unit = "onopen" [@@mel.set]
  end
end

module WebSocketPair = struct
  type t = WebSocket.t * WebSocket.t

  type pair_object

  external make_ : unit -> pair_object = "WebSocketPair" [@@mel.new]

  external get_0 : pair_object -> WebSocket.t = "0" [@@mel.get]
  external get_1 : pair_object -> WebSocket.t = "1" [@@mel.get]

  let make () =
    let pair = make_ () in
    (get_0 pair, get_1 pair)
end

(** {1 Durable Objects} *)

module DurableObject = struct
  module Namespace = struct
    type t

    type durable_object_id

    external idFromName : t -> string -> durable_object_id = "idFromName" [@@mel.send]

    external idFromString : t -> string -> durable_object_id = "idFromString" [@@mel.send]

    external newUniqueId : t -> durable_object_id = "newUniqueId" [@@mel.send]

    type durable_object_stub

    external get : t -> durable_object_id -> durable_object_stub = "get" [@@mel.send]
  end

  type durable_object_id = Namespace.durable_object_id
  type durable_object_stub = Namespace.durable_object_stub

  module Id = struct
    external toString : durable_object_id -> string = "toString" [@@mel.send]

    external equals : durable_object_id -> durable_object_id -> bool = "equals" [@@mel.send]
  end

  module Stub = struct
    external fetch : durable_object_stub -> Request.t -> Response.t Js.Promise.t =
      "fetch" [@@mel.send]

    let fetch_url stub url =
      let req = Request.make url in
      fetch stub req

    external id : durable_object_stub -> durable_object_id = "id" [@@mel.get]
  end

  module Storage = struct
    type t

    external get : t -> string -> Js.Json.t option Js.Promise.t = "get" [@@mel.send]

    external get_multiple : t -> string array -> (string * Js.Json.t) array Js.Promise.t =
      "get" [@@mel.send]

    external put : t -> string -> Js.Json.t -> unit Js.Promise.t = "put" [@@mel.send]

    external put_multiple : t -> (string * Js.Json.t) array -> unit Js.Promise.t =
      "put" [@@mel.send]

    external delete : t -> string -> bool Js.Promise.t = "delete" [@@mel.send]

    external delete_multiple : t -> string array -> int Js.Promise.t =
      "delete" [@@mel.send]

    external list : t -> (string * Js.Json.t) array Js.Promise.t = "list" [@@mel.send]

    external deleteAll : t -> unit Js.Promise.t = "deleteAll" [@@mel.send]
  end

  module State = struct
    type t

    external storage : t -> Storage.t = "storage" [@@mel.get]

    external id : t -> durable_object_id = "id" [@@mel.get]

    external waitUntil : t -> 'a Js.Promise.t -> unit = "waitUntil" [@@mel.send]

    external blockConcurrencyWhile : t -> 'a Js.Promise.t -> 'a Js.Promise.t =
      "blockConcurrencyWhile" [@@mel.send]
  end
end

(** {1 Environment Variable Access} *)

(* Use Js.Dict for dynamic property access on env object *)
external unsafeGet : 'a Js.Dict.t -> string -> 'b option = "get"
  [@@mel.send] [@@mel.return nullable]

let get_env_var (env : 'env) (key : string) : 'a option =
  unsafeGet (Obj.magic env : 'a Js.Dict.t) key

let get_env_string (env : 'env) (key : string) : string option =
  unsafeGet (Obj.magic env : string Js.Dict.t) key

(** {1 Modern Workers Handlers} *)

module Handler = struct
  type 'env fetch_handler = Request.t -> 'env -> ExecutionContext.t -> Response.t Js.Promise.t
  type 'env scheduled_handler = 'env ScheduledEvent.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t
  type 'env queue_handler = QueueEvent.Batch.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t
  type 'env email_handler = EmailEvent.Message.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t
  type 'env tail_handler = tail_item array -> 'env -> ExecutionContext.t -> unit Js.Promise.t
  and tail_item

  type alarm_handler = alarm_info option -> unit Js.Promise.t
  and alarm_info

  external alarm_retry_count : alarm_info -> int = "retryCount" [@@mel.get]
  external alarm_is_retry : alarm_info -> bool = "isRetry" [@@mel.get]

  (* Tail item accessors *)
  external tail_script_name : tail_item -> string = "scriptName" [@@mel.get]
  external tail_event_timestamp : tail_item -> float = "eventTimestamp" [@@mel.get]
  external tail_outcome : tail_item -> string = "outcome" [@@mel.get]
  external tail_logs : tail_item -> Js.Json.t array = "logs" [@@mel.get]
  external tail_exceptions : tail_item -> Js.Json.t array = "exceptions" [@@mel.get]

  type 'env t

  external make :
    ?fetch:('env fetch_handler) ->
    ?scheduled:('env scheduled_handler) ->
    ?queue:('env queue_handler) ->
    ?email:('env email_handler) ->
    ?tail:('env tail_handler) ->
    ?alarm:alarm_handler ->
    unit ->
    'env t = "" [@@mel.obj]
end

(** {1 WorkerEntrypoint (RPC Service Bindings)} *)

module WorkerEntrypoint = struct
  (* Re-export handler types for convenience *)
  type 'env fetch_handler = Request.t -> 'env -> ExecutionContext.t -> Response.t Js.Promise.t
  type 'env scheduled_handler = 'env ScheduledEvent.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t
  type 'env queue_handler = QueueEvent.Batch.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t
  type 'env email_handler = EmailEvent.Message.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t
  type 'env tail_handler = Handler.tail_item array -> 'env -> ExecutionContext.t -> unit Js.Promise.t
  type alarm_handler = Handler.alarm_info option -> unit Js.Promise.t

  (* The WorkerEntrypoint class type *)
  type 'env t

  (* Internal: Create a handlers object to pass to the JavaScript shim *)
  type 'env handlers_obj

  external make_handlers_obj :
    ?fetch:('env fetch_handler) ->
    ?scheduled:('env scheduled_handler) ->
    ?queue:('env queue_handler) ->
    ?email:('env email_handler) ->
    ?tail:('env tail_handler) ->
    ?alarm:alarm_handler ->
    unit ->
    'env handlers_obj = "" [@@mel.obj]

  (* External binding to the JavaScript shim function *)
  external make_worker_entrypoint_internal : 'env handlers_obj -> 'env t =
    "makeWorkerEntrypoint"
    [@@mel.module "./worker_entrypoint_shim.js"]

  (* Public API: Create a WorkerEntrypoint with handlers *)
  let make ?fetch ?scheduled ?queue ?email ?tail ?alarm () =
    let handlers = make_handlers_obj ?fetch ?scheduled ?queue ?email ?tail ?alarm () in
    make_worker_entrypoint_internal handlers
end
