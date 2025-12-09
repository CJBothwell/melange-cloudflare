(** Cloudflare Workers Runtime API.

    This module provides bindings to the Cloudflare Workers runtime environment,
    including the fetch event handler, environment variables, execution context,
    and various Workers-specific APIs like scheduled events, queues, and Durable Objects.

    @author Melange Cloudflare Bindings
    @version 1.0.0
*)

open Cloudflare

(** {1 Workers Environment} *)

(** The base environment bindings available to all Workers.

    This represents the 'env' parameter passed to fetch handlers and other
    event handlers. Users typically extend this with their own bindings.
*)
module type ENV = sig
  (** The environment type. Extend this in your application to add your
      specific bindings (KV namespaces, D1 databases, R2 buckets, etc.). *)
  type t
end

(** {1 Execution Context} *)

(** The execution context provides methods to extend the lifetime of a Worker
    and wait for asynchronous tasks to complete.
*)
module ExecutionContext : sig
  (** The type representing an execution context. *)
  type t

  (** [waitUntil ctx promise] extends the lifetime of the request handler.

      This tells the Workers runtime to keep the Worker alive until [promise]
      settles, even after the response has been returned. This is useful for
      logging, analytics, or cleanup tasks that shouldn't delay the response.

      @param ctx The execution context.
      @param promise A Promise representing the async task to wait for.

      Example: [waitUntil ctx (log_analytics_promise)]
  *)
  val waitUntil : t -> 'a Js.Promise.t -> unit

  (** [passThroughOnException ctx] prevents the Worker from handling exceptions.

      If called, the Worker will fail open, allowing the request to pass through
      to the origin server rather than returning an error response.

      @param ctx The execution context.
  *)
  val passThroughOnException : t -> unit
end

(** {1 Fetch Event Handler} *)

(** Fetch event request handler.

    The primary event handler for HTTP requests in Cloudflare Workers.
*)
module FetchEvent : sig
  (** Type of the fetch handler function.

      @param request The incoming HTTP request.
      @param env The environment bindings (KV, D1, secrets, etc.).
      @param ctx The execution context for managing async tasks.
      @return A Promise that resolves to a Response.
  *)
  type 'env handler = Request.t -> 'env -> ExecutionContext.t -> Response.t Js.Promise.t

  (** [on_fetch handler] registers the fetch event handler.

      This is the main entry point for a Cloudflare Worker. The handler will be
      called for each incoming HTTP request.

      @param handler The function to handle incoming requests.

      Example:
      {[
        let () = FetchEvent.on_fetch (fun request env ctx ->
          Response.make_ok (String "Hello World!") None
          |> Js.Promise.resolve
        )
      ]}
  *)
  val on_fetch : 'env handler -> unit
end

(** {1 Scheduled Event Handler} *)

(** Scheduled event handler for Cron Triggers.

    Allows Workers to run on a schedule using Cron expressions.
*)
module ScheduledEvent : sig
  (** The scheduled event object parameterized by environment type. *)
  type 'env t

  (** [scheduledTime event] gets the scheduled time in milliseconds since epoch.

      @param event The scheduled event.
      @return The timestamp in milliseconds.
  *)
  val scheduledTime : 'env t -> float

  (** [cron event] gets the Cron expression that triggered this event.

      @param event The scheduled event.
      @return The Cron expression string (e.g., "0 0 * * *").
  *)
  val cron : 'env t -> string

  (** Type of the scheduled handler function.

      @param event The scheduled event details.
      @param env The environment bindings.
      @param ctx The execution context.
      @return A Promise that resolves when processing is complete.
  *)
  type 'env handler = 'env t -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (** [on_scheduled handler] registers the scheduled event handler.

      @param handler The function to handle scheduled events.

      Example:
      {[
        let () = ScheduledEvent.on_scheduled (fun event env ctx ->
          (* Run scheduled task *)
          cleanup_old_data env
        )
      ]}
  *)
  val on_scheduled : 'env handler -> unit
end

(** {1 Queue Consumer} *)

(** Queue consumer for processing messages from Cloudflare Queues.

    Workers can consume messages from queues in batches.
*)
module QueueEvent : sig
  (** A single queue message. *)
  module Message : sig
    (** The type representing a queue message. *)
    type t

    (** [id msg] gets the unique message ID.

        @param msg The message.
        @return The message ID string.
    *)
    val id : t -> string

    (** [timestamp msg] gets the message timestamp.

        @param msg The message.
        @return The timestamp in milliseconds since epoch.
    *)
    val timestamp : t -> float

    (** [body msg] gets the message body as JSON.

        @param msg The message.
        @return The parsed JSON body.
    *)
    val body : t -> Js.Json.t

    (** [body_text msg] gets the message body as text.

        @param msg The message.
        @return The body as a string.
    *)
    val body_text : t -> string

    (** [retry msg] marks the message for retry.

        @param msg The message.
    *)
    val retry : t -> unit

    (** [ack msg] acknowledges the message.

        @param msg The message.
    *)
    val ack : t -> unit
  end

  (** A batch of queue messages. *)
  module Batch : sig
    (** The type representing a batch of messages. *)
    type t

    (** [queue batch] gets the queue name.

        @param batch The message batch.
        @return The queue name string.
    *)
    val queue : t -> string

    (** [messages batch] gets all messages in the batch.

        @param batch The message batch.
        @return An array of messages.
    *)
    val messages : t -> Message.t array

    (** [retryAll batch] marks all messages in the batch for retry.

        @param batch The message batch.
    *)
    val retryAll : t -> unit

    (** [ackAll batch] acknowledges all messages in the batch.

        @param batch The message batch.
    *)
    val ackAll : t -> unit
  end

  (** Type of the queue handler function.

      @param batch The batch of messages to process.
      @param env The environment bindings.
      @param ctx The execution context.
      @return A Promise that resolves when processing is complete.
  *)
  type 'env handler = Batch.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (** [on_queue handler] registers the queue consumer handler.

      @param handler The function to handle message batches.

      Example:
      {[
        let () = QueueEvent.on_queue (fun batch env ctx ->
          let messages = Batch.messages batch in
          Array.iter (fun msg ->
            (* Process message *)
            Message.ack msg
          ) messages;
          Js.Promise.resolve ()
        )
      ]}
  *)
  val on_queue : 'env handler -> unit
end

(** {1 Email Event Handler} *)

(** Email event handler for Email Workers.

    Workers can receive and process incoming emails.
*)
module EmailEvent : sig
  (** An email message. *)
  module Message : sig
    (** The type representing an email message. *)
    type t

    (** [from msg] gets the sender email address.

        @param msg The email message.
        @return The sender's email address.
    *)
    val from : t -> string

    (** [to_ msg] gets the recipient email address.

        @param msg The email message.
        @return The recipient's email address.
    *)
    val to_ : t -> string

    (** [headers msg] gets the email headers.

        @param msg The email message.
        @return The Headers object.
    *)
    val headers : t -> Headers.t

    (** [raw msg] gets the raw email content.

        @param msg The email message.
        @return A ReadableStream of the raw email.
    *)
    val raw : t -> readableStream

    (** [rawSize msg] gets the size of the raw email in bytes.

        @param msg The email message.
        @return The size in bytes.
    *)
    val rawSize : t -> int

    (** [forward msg to_address] forwards the email to another address.

        @param msg The email message.
        @param to_address The destination email address.
        @return A Promise that resolves when forwarding is complete.
    *)
    val forward : t -> string -> unit Js.Promise.t

    (** [setReject msg reason] rejects the email with a reason.

        @param msg The email message.
        @param reason The rejection reason.
    *)
    val setReject : t -> string -> unit
  end

  (** Type of the email handler function.

      @param message The incoming email message.
      @param env The environment bindings.
      @param ctx The execution context.
      @return A Promise that resolves when processing is complete.
  *)
  type 'env handler = Message.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (** [on_email handler] registers the email event handler.

      @param handler The function to handle incoming emails.
  *)
  val on_email : 'env handler -> unit
end

(** {1 Cache API} *)

(** The Cache API allows you to store and retrieve HTTP responses.

    Cloudflare Workers have access to a global cache that can be used to
    store responses and reduce latency for repeated requests.
*)
module Cache : sig
  (** The type representing a cache instance. *)
  type t

  (** [default ()] gets the default cache.

      @return The default cache instance.
  *)
  val default : unit -> t

  (** [open_ cache_name] opens a named cache.

      @param cache_name The name of the cache to open.
      @return A Promise that resolves to the cache instance.
  *)
  val open_ : string -> t Js.Promise.t

  (** [match_ cache request] looks up a request in the cache.

      @param cache The cache instance.
      @param request The request to look up (or a URL string).
      @return A Promise that resolves to [Some response] if found, [None] otherwise.
  *)
  val match_ : t -> Request.t -> Response.t option Js.Promise.t

  (** [match_url cache url] looks up a URL in the cache.

      @param cache The cache instance.
      @param url The URL string to look up.
      @return A Promise that resolves to [Some response] if found, [None] otherwise.
  *)
  val match_url : t -> string -> Response.t option Js.Promise.t

  (** [put cache request response] stores a response in the cache.

      @param cache The cache instance.
      @param request The request to use as the cache key.
      @param response The response to cache.
      @return A Promise that resolves when the response is stored.
  *)
  val put : t -> Request.t -> Response.t -> unit Js.Promise.t

  (** [put_url cache url response] stores a response in the cache with a URL key.

      @param cache The cache instance.
      @param url The URL string to use as the cache key.
      @param response The response to cache.
      @return A Promise that resolves when the response is stored.
  *)
  val put_url : t -> string -> Response.t -> unit Js.Promise.t

  (** [delete cache request] removes a request from the cache.

      @param cache The cache instance.
      @param request The request to remove.
      @return A Promise that resolves to [true] if deleted, [false] if not found.
  *)
  val delete : t -> Request.t -> bool Js.Promise.t

  (** [delete_url cache url] removes a URL from the cache.

      @param cache The cache instance.
      @param url The URL string to remove.
      @return A Promise that resolves to [true] if deleted, [false] if not found.
  *)
  val delete_url : t -> string -> bool Js.Promise.t
end

(** {1 Crypto API} *)

(** The Web Crypto API for cryptographic operations.

    Provides cryptographic primitives including hashing, signing, encryption,
    and random number generation.
*)
module Crypto : sig
  (** [getRandomValues array] fills an array with cryptographically strong random values.

      @param array A TypedArray to fill with random values.
      @return The same array, filled with random values.
  *)
  val getRandomValues : Js.Typed_array.Uint8Array.t -> Js.Typed_array.Uint8Array.t

  (** [randomUUID ()] generates a random UUID v4.

      @return A UUID string (e.g., "550e8400-e29b-41d4-a716-446655440000").
  *)
  val randomUUID : unit -> string

  (** SubtleCrypto API for advanced cryptographic operations. *)
  module Subtle : sig
    (** The type representing the SubtleCrypto interface. *)
    type t

    (** Hash algorithm identifiers. *)
    type hash_algorithm =
      | SHA_1  (** SHA-1 (not recommended for security-critical applications) *)
      | SHA_256  (** SHA-256 *)
      | SHA_384  (** SHA-384 *)
      | SHA_512  (** SHA-512 *)

    (** [digest alg data] computes a cryptographic hash.

        @param alg The hash algorithm to use.
        @param data The data to hash (ArrayBuffer).
        @return A Promise that resolves to the hash as an ArrayBuffer.
    *)
    val digest : hash_algorithm -> Fetch.arrayBuffer ->
      Fetch.arrayBuffer Js.Promise.t

    (** [digest_string alg data] computes a hash of a string.

        @param alg The hash algorithm to use.
        @param data The string to hash.
        @return A Promise that resolves to the hash as an ArrayBuffer.
    *)
    val digest_string : hash_algorithm -> string ->
      Fetch.arrayBuffer Js.Promise.t
  end

  (** [subtle ()] gets the SubtleCrypto interface.

      @return The SubtleCrypto instance.
  *)
  val subtle : unit -> Subtle.t
end

(** {1 HTMLRewriter} *)

(** The HTMLRewriter API for transforming HTML content.

    HTMLRewriter allows you to parse and transform HTML on the fly using
    streaming parsing, without loading the entire document into memory.
*)
module HTMLRewriter : sig
  (** The type representing an HTMLRewriter instance. *)
  type t

  (** Element handler for transforming HTML elements. *)
  module ElementHandler : sig
    (** The type representing an HTML element. *)
    type element

    (** [tagName el] gets the element's tag name.

        @param el The element.
        @return The tag name in lowercase (e.g., "div", "span").
    *)
    val tagName : element -> string

    (** [getAttribute el name] gets an attribute value.

        @param el The element.
        @param name The attribute name.
        @return [Some value] if the attribute exists, [None] otherwise.
    *)
    val getAttribute : element -> string -> string option

    (** [setAttribute el name value] sets an attribute.

        @param el The element.
        @param name The attribute name.
        @param value The attribute value.
    *)
    val setAttribute : element -> string -> string -> unit

    (** [removeAttribute el name] removes an attribute.

        @param el The element.
        @param name The attribute name to remove.
    *)
    val removeAttribute : element -> string -> unit

    (** [hasAttribute el name] checks if an attribute exists.

        @param el The element.
        @param name The attribute name to check.
        @return [true] if the attribute exists, [false] otherwise.
    *)
    val hasAttribute : element -> string -> bool

    (** [before el content] inserts content before the element.

        @param el The element.
        @param content HTML content to insert.
    *)
    val before : element -> string -> unit

    (** [after el content] inserts content after the element.

        @param el The element.
        @param content HTML content to insert.
    *)
    val after : element -> string -> unit

    (** [prepend el content] inserts content at the start of the element.

        @param el The element.
        @param content HTML content to prepend.
    *)
    val prepend : element -> string -> unit

    (** [append el content] inserts content at the end of the element.

        @param el The element.
        @param content HTML content to append.
    *)
    val append : element -> string -> unit

    (** [replace el content] replaces the element with content.

        @param el The element.
        @param content HTML content to replace the element with.
    *)
    val replace : element -> string -> unit

    (** [remove el] removes the element.

        @param el The element to remove.
    *)
    val remove : element -> unit

    (** [removeAndKeepContent el] removes the element but keeps its children.

        @param el The element.
    *)
    val removeAndKeepContent : element -> unit

    (** Element handler callbacks. *)
    type handlers = {
      element : (element -> unit) option;  (** Called for each matching element *)
      comments : (string -> unit) option;  (** Called for HTML comments *)
      text : (string -> unit) option;  (** Called for text nodes *)
    }
  end

  (** [make ()] creates a new HTMLRewriter instance.

      @return A new HTMLRewriter.
  *)
  val make : unit -> t

  (** [on t selector handlers] registers handlers for a CSS selector.

      @param t The HTMLRewriter instance.
      @param selector A CSS selector (e.g., "div.class", "#id", "a[href]").
      @param handlers Callbacks for elements, comments, and text nodes.
      @return The HTMLRewriter instance (for chaining).
  *)
  val on : t -> string -> ElementHandler.handlers -> t

  (** [onDocument t handlers] registers handlers for the entire document.

      @param t The HTMLRewriter instance.
      @param handlers Document-level callbacks.
      @return The HTMLRewriter instance (for chaining).
  *)
  val onDocument : t -> ElementHandler.handlers -> t

  (** [transform t response] applies the transformations to a response.

      @param t The HTMLRewriter instance.
      @param response The response containing HTML to transform.
      @return A new Response with the transformed HTML.
  *)
  val transform : t -> Response.t -> Response.t
end

(** {1 WebSocket} *)

(** WebSocket API for bidirectional communication.

    Workers can accept WebSocket connections and communicate with clients
    in real-time.
*)
module WebSocket : sig
  (** The type representing a WebSocket connection. *)
  type t

  (** WebSocket ready states. *)
  type ready_state =
    | Connecting  (** Connection is being established *)
    | Open  (** Connection is open and ready *)
    | Closing  (** Connection is closing *)
    | Closed  (** Connection is closed *)

  (** [readyState ws] gets the current connection state.

      @param ws The WebSocket.
      @return The ready state.
  *)
  val readyState : t -> ready_state

  (** [url ws] gets the WebSocket URL.

      @param ws The WebSocket.
      @return The URL string.
  *)
  val url : t -> string

  (** [send ws data] sends a message.

      @param ws The WebSocket.
      @param data The message data (string or ArrayBuffer).
  *)
  val send : t -> string -> unit

  (** [send_buffer ws buffer] sends binary data.

      @param ws The WebSocket.
      @param buffer The binary data to send.
  *)
  val send_buffer : t -> Fetch.arrayBuffer -> unit

  (** [close ws] closes the connection with default code (1000).

      @param ws The WebSocket.
  *)
  val close : t -> unit

  (** [close_with_code ws code reason] closes the connection with a code and reason.

      @param ws The WebSocket.
      @param code The close code (1000-4999).
      @param reason Optional close reason string.
  *)
  val close_with_code : t -> int -> string option -> unit

  (** [accept ws] accepts a WebSocket connection from a client.

      This must be called in response to a WebSocket upgrade request.

      @param ws The WebSocket to accept.
  *)
  val accept : t -> unit

  (** WebSocket event handlers. *)
  module Events : sig
    (** [onMessage ws handler] registers a message handler.

        @param ws The WebSocket.
        @param handler Function called with the message data.
    *)
    val onMessage : t -> (string -> unit) -> unit

    (** [onClose ws handler] registers a close handler.

        @param ws The WebSocket.
        @param handler Function called with (code, reason, wasClean).
    *)
    val onClose : t -> (int -> string -> bool -> unit) -> unit

    (** [onError ws handler] registers an error handler.

        @param ws The WebSocket.
        @param handler Function called when an error occurs.
    *)
    val onError : t -> (Js.Exn.t -> unit) -> unit

    (** [onOpen ws handler] registers an open handler.

        @param ws The WebSocket.
        @param handler Function called when the connection opens.
    *)
    val onOpen : t -> (unit -> unit) -> unit
  end
end

(** WebSocketPair represents a pair of connected WebSockets.

    This is used to create a bidirectional channel where messages sent to
    one socket are received by the other.
*)
module WebSocketPair : sig
  (** The type representing a WebSocket pair. *)
  type t = WebSocket.t * WebSocket.t

  (** [make ()] creates a new pair of connected WebSockets.

      @return A tuple of (client_socket, server_socket).
  *)
  val make : unit -> t
end

(** {1 Durable Objects} *)

(** Durable Objects provide strongly consistent coordination primitives.

    Durable Objects are isolated instances that can maintain state and
    coordinate between multiple clients with strong consistency guarantees.
*)
module DurableObject : sig
  (** Durable Object ID. *)
  type durable_object_id

  (** Durable Object stub for making requests. *)
  type durable_object_stub

  (** Durable Object namespace for accessing instances. *)
  module Namespace : sig
    (** The type representing a Durable Object namespace binding. *)
    type t

    (** [idFromName ns name] gets a Durable Object ID from a name.

        Objects with the same name always map to the same ID.

        @param ns The namespace.
        @param name The object name.
        @return A Durable Object ID.
    *)
    val idFromName : t -> string -> durable_object_id

    (** [idFromString ns str] deserializes a Durable Object ID from a string.

        @param ns The namespace.
        @param str The serialized ID string.
        @return A Durable Object ID.
    *)
    val idFromString : t -> string -> durable_object_id

    (** [newUniqueId ns] generates a new unique Durable Object ID.

        @param ns The namespace.
        @return A new unique Durable Object ID.
    *)
    val newUniqueId : t -> durable_object_id

    (** [get ns id] gets a stub for communicating with a Durable Object.

        @param ns The namespace.
        @param id The Durable Object ID.
        @return A stub for making requests to the object.
    *)
    val get : t -> durable_object_id -> durable_object_stub
  end

  (** Durable Object ID operations. *)
  module Id : sig
    (** [toString id] serializes an ID to a string.

        @param id The Durable Object ID.
        @return The serialized ID string.
    *)
    val toString : durable_object_id -> string

    (** [equals id1 id2] checks if two IDs are equal.

        @param id1 The first ID.
        @param id2 The second ID.
        @return [true] if equal, [false] otherwise.
    *)
    val equals : durable_object_id -> durable_object_id -> bool
  end

  (** Durable Object stub operations. *)
  module Stub : sig
    (** [fetch stub request] sends an HTTP request to the Durable Object.

        @param stub The Durable Object stub.
        @param request The request to send.
        @return A Promise that resolves to the response.
    *)
    val fetch : durable_object_stub -> Request.t -> Response.t Js.Promise.t

    (** [fetch_url stub url] sends a GET request to the Durable Object.

        @param stub The Durable Object stub.
        @param url The URL path.
        @return A Promise that resolves to the response.
    *)
    val fetch_url : durable_object_stub -> string -> Response.t Js.Promise.t

    (** [id stub] gets the Durable Object ID.

        @param stub The Durable Object stub.
        @return The Durable Object ID.
    *)
    val id : durable_object_stub -> durable_object_id
  end

  (** Durable Object storage API for persisting state. *)
  module Storage : sig
    (** The type representing Durable Object storage. *)
    type t

    (** [get storage key] retrieves a value by key.

        @param storage The storage instance.
        @param key The key to retrieve.
        @return A Promise that resolves to [Some value] if found, [None] otherwise.
    *)
    val get : t -> string -> Js.Json.t option Js.Promise.t

    (** [get_multiple storage keys] retrieves multiple values.

        @param storage The storage instance.
        @param keys An array of keys to retrieve.
        @return A Promise that resolves to a map of key-value pairs.
    *)
    val get_multiple : t -> string array -> (string * Js.Json.t) array Js.Promise.t

    (** [put storage key value] stores a value.

        @param storage The storage instance.
        @param key The key to store.
        @param value The value to store (any JSON-serializable value).
        @return A Promise that resolves when the value is stored.
    *)
    val put : t -> string -> Js.Json.t -> unit Js.Promise.t

    (** [put_multiple storage entries] stores multiple values.

        @param storage The storage instance.
        @param entries An array of (key, value) pairs.
        @return A Promise that resolves when all values are stored.
    *)
    val put_multiple : t -> (string * Js.Json.t) array -> unit Js.Promise.t

    (** [delete storage key] deletes a value.

        @param storage The storage instance.
        @param key The key to delete.
        @return A Promise that resolves to [true] if deleted, [false] if not found.
    *)
    val delete : t -> string -> bool Js.Promise.t

    (** [delete_multiple storage keys] deletes multiple values.

        @param storage The storage instance.
        @param keys An array of keys to delete.
        @return A Promise that resolves to the number of keys deleted.
    *)
    val delete_multiple : t -> string array -> int Js.Promise.t

    (** [list storage] lists all keys.

        @param storage The storage instance.
        @return A Promise that resolves to a map of all key-value pairs.
    *)
    val list : t -> (string * Js.Json.t) array Js.Promise.t

    (** [deleteAll storage] deletes all keys.

        @param storage The storage instance.
        @return A Promise that resolves when all keys are deleted.
    *)
    val deleteAll : t -> unit Js.Promise.t
  end

  (** Durable Object state interface. *)
  module State : sig
    (** The type representing Durable Object state. *)
    type t

    (** [storage state] gets the storage interface.

        @param state The Durable Object state.
        @return The storage instance.
    *)
    val storage : t -> Storage.t

    (** [id state] gets the Durable Object ID.

        @param state The Durable Object state.
        @return The Durable Object ID.
    *)
    val id : t -> durable_object_id

    (** [waitUntil state promise] extends the object's lifetime.

        @param state The Durable Object state.
        @param promise A Promise to wait for.
    *)
    val waitUntil : t -> 'a Js.Promise.t -> unit

    (** [blockConcurrencyWhile state promise] blocks concurrent requests.

        Prevents other requests from being processed until the promise resolves.

        @param state The Durable Object state.
        @param promise A Promise to wait for.
        @return A Promise that resolves with the original promise's value.
    *)
    val blockConcurrencyWhile : t -> 'a Js.Promise.t -> 'a Js.Promise.t
  end
end

(** {1 Environment Variable Access} *)

(** [get_env_var env key] retrieves an environment variable or binding.

    This is a low-level function to access any binding from the environment.
    For typed access to specific services (KV, D1, R2), use the service-specific
    modules instead.

    @param env The environment object.
    @param key The binding name.
    @return [Some value] if the binding exists, [None] otherwise.
*)
val get_env_var : 'env -> string -> 'a option

(** [get_env_string env key] retrieves a string environment variable.

    @param env The environment object.
    @param key The variable name.
    @return [Some value] if the variable exists, [None] otherwise.
*)
val get_env_string : 'env -> string -> string option

(** {1 Modern Workers Handlers API} *)

(** Modern Workers handler API using ES6 module exports.

    This is the recommended way to define Workers handlers. Instead of using
    the legacy addEventListener pattern, you export a default object with
    handler methods.

    The modern API provides:
    - Cleaner, more declarative syntax
    - Better TypeScript/type inference support
    - Follows current Cloudflare Workers best practices
    - Supports all handler types in one export

    {2 Basic Usage}

    {[
      open Cloudflare
      open Workers

      type env = {
        (* Your bindings here *)
      }

      let fetch_handler request env ctx =
        let json = Js.Json.string "Hello from OCaml!" in
        let init = { Response.status = Some 200; statusText = None; headers = None } in
        Js.Promise.resolve (Response.make_json_with_init json init)

      let default = Handler.make ~fetch:fetch_handler ()
    ]}

    {2 Multiple Handlers}

    You can combine multiple handlers in a single Worker:

    {[
      let fetch_handler request env ctx =
        (* Handle HTTP requests *)
        ...

      let scheduled_handler event env ctx =
        (* Handle cron triggers *)
        Js.log "Running scheduled task";
        Js.Promise.resolve ()

      let queue_handler batch env ctx =
        (* Handle queue messages *)
        ...

      let default = Handler.make
        ~fetch:fetch_handler
        ~scheduled:scheduled_handler
        ~queue:queue_handler
        ()
    ]}

    @see <https://developers.cloudflare.com/workers/runtime-apis/handlers/> Cloudflare Workers Handlers Documentation
*)
module Handler : sig
  (** {2 Handler Type Definitions} *)

  (** Fetch handler processes incoming HTTP requests.

      @param request The incoming HTTP request
      @param env The environment bindings
      @param ctx The execution context
      @return A Promise resolving to an HTTP response
  *)
  type 'env fetch_handler = Request.t -> 'env -> ExecutionContext.t -> Response.t Js.Promise.t

  (** Scheduled handler processes cron triggers.

      @param event The scheduled event with timing information
      @param env The environment bindings
      @param ctx The execution context
      @return A Promise resolving when processing is complete
  *)
  type 'env scheduled_handler = 'env ScheduledEvent.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (** Queue handler processes messages from Cloudflare Queues.

      @param batch The batch of queue messages to process
      @param env The environment bindings
      @param ctx The execution context
      @return A Promise resolving when processing is complete
  *)
  type 'env queue_handler = QueueEvent.Batch.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (** Email handler processes incoming emails via Email Routing.

      @param message The incoming email message
      @param env The environment bindings
      @param ctx The execution context
      @return A Promise resolving when processing is complete
  *)
  type 'env email_handler = EmailEvent.Message.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (** Tail handler processes execution logs from other Workers.

      Tail workers receive batches of execution events from producer Workers,
      enabling real-time log processing and analytics.

      @param events Array of tail items representing Worker executions
      @param env The environment bindings
      @param ctx The execution context
      @return A Promise resolving when processing is complete
  *)
  type 'env tail_handler = tail_item array -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (** Tail item represents a single Worker execution event.

      Contains information about a Worker's execution including logs,
      exceptions, outcome, and performance metrics.
  *)
  and tail_item

  (** Alarm handler processes Durable Object alarms.

      Alarms are time-based triggers for Durable Objects, enabling scheduled
      work without requiring incoming requests.

      @param info Optional alarm information including retry count
      @return A Promise resolving when processing is complete
  *)
  type alarm_handler = alarm_info option -> unit Js.Promise.t

  (** Alarm info contains retry information for alarm handlers. *)
  and alarm_info

  (** [alarm_retry_count info] gets the number of times this alarm has been retried.

      @param info The alarm info object.
      @return The retry count (0 on first attempt).
  *)
  val alarm_retry_count : alarm_info -> int

  (** [alarm_is_retry info] checks if this is a retry attempt.

      @param info The alarm info object.
      @return [true] if this is a retry, [false] on first attempt.
  *)
  val alarm_is_retry : alarm_info -> bool

  (** {2 Tail Item Accessors} *)

  (** [tail_script_name item] gets the name of the Worker that generated this event.

      @param item The tail item.
      @return The script name.
  *)
  val tail_script_name : tail_item -> string

  (** [tail_event_timestamp item] gets the Unix timestamp when the event occurred.

      @param item The tail item.
      @return Milliseconds since epoch.
  *)
  val tail_event_timestamp : tail_item -> float

  (** [tail_outcome item] gets the execution outcome.

      Possible values: "ok", "exception", "exceededCpu", "exceededMemory", "unknown"

      @param item The tail item.
      @return The outcome string.
  *)
  val tail_outcome : tail_item -> string

  (** [tail_logs item] gets the console logs from the execution.

      @param item The tail item.
      @return Array of log entries.
  *)
  val tail_logs : tail_item -> Js.Json.t array

  (** [tail_exceptions item] gets the exceptions that occurred during execution.

      @param item The tail item.
      @return Array of exception objects.
  *)
  val tail_exceptions : tail_item -> Js.Json.t array

  (** {2 Handler Object Type} *)

  (** The handler object type parameterized by environment type.

      This is the type of the default export object containing your handlers.
  *)
  type 'env t

  (** {2 Creating Handler Objects} *)

  (** [make ?fetch ?scheduled ?queue ?email ?tail ?alarm ()] creates a handler object.

      All handlers are optional - include only the ones your Worker needs.
      The resulting object should be exported as your Worker's default export.

      @param fetch Optional fetch handler for HTTP requests
      @param scheduled Optional scheduled handler for cron triggers
      @param queue Optional queue handler for processing queue messages
      @param email Optional email handler for incoming emails
      @param tail Optional tail handler for processing execution logs
      @param alarm Optional alarm handler for Durable Object alarms
      @return A handler object ready to be exported as default

      Example:
      {[
        let fetch_handler request env ctx =
          Response.make_json (Js.Json.string "Hello") {...}
          |> Js.Promise.resolve

        let scheduled_handler event env ctx =
          Js.log "Cron executed";
          Js.Promise.resolve ()

        let default = Handler.make
          ~fetch:fetch_handler
          ~scheduled:scheduled_handler
          ()
      ]}
  *)
  val make :
    ?fetch:('env fetch_handler) ->
    ?scheduled:('env scheduled_handler) ->
    ?queue:('env queue_handler) ->
    ?email:('env email_handler) ->
    ?tail:('env tail_handler) ->
    ?alarm:alarm_handler ->
    unit ->
    'env t
end

(** {1 WorkerEntrypoint (RPC Service Bindings)} *)

(** WorkerEntrypoint provides a class-based API for Cloudflare Workers with RPC support.

    WorkerEntrypoint extends the standard Workers API to enable:
    - RPC (Remote Procedure Call) between Workers via service bindings
    - Class-based worker organization with multiple handler methods
    - Access to environment bindings through instance properties
    - Enhanced type safety for service-to-service communication

    {2 When to Use WorkerEntrypoint}

    Use WorkerEntrypoint when you need:
    - RPC calls between Workers using service bindings
    - A class-based API structure (required for certain features)
    - Multiple handler types in a single Worker (fetch, scheduled, etc.)
    - To expose custom methods that other Workers can call via RPC

    For simple Workers that only handle HTTP requests, the {!Handler} module
    may be more straightforward.

    {2 Basic Usage}

    {[
      open Cloudflare
      open Workers

      type env = {
        (* Your bindings here *)
      }

      let fetch_handler request env ctx =
        let json = Js.Json.string "Hello from WorkerEntrypoint!" in
        Response.make_json json
        |> Js.Promise.resolve

      let default = WorkerEntrypoint.make ~fetch:fetch_handler ()
    ]}

    {2 RPC Usage}

    WorkerEntrypoint is primarily used for RPC (Remote Procedure Call) patterns
    where one Worker can call methods on another Worker via service bindings:

    {[
      (* In your Worker that exposes RPC methods *)
      let fetch_handler request env ctx =
        (* Handle HTTP requests *)
        ...

      (* Custom RPC method - callable from other Workers *)
      let get_user_data user_id env =
        (* Query database, return user data *)
        ...

      let default = WorkerEntrypoint.make_with_rpc
        ~fetch:fetch_handler
        ~methods:[("getUserData", get_user_data)]
        ()
    ]}

    {2 Comparison with Handler Module}

    - {!Handler}: Simple object exports, best for standard Workers
    - {!WorkerEntrypoint}: Class-based, required for RPC and service bindings

    Both compile to valid Cloudflare Workers code, but WorkerEntrypoint
    generates an ES6 class that extends the WorkerEntrypoint base class.

    @see <https://developers.cloudflare.com/workers/runtime-apis/bindings/service-bindings/rpc/> RPC Documentation
*)
module WorkerEntrypoint : sig
  (** {2 Handler Type Definitions}

      These types are re-exported from the Handler module for convenience.
      WorkerEntrypoint uses the same handler signatures as the Handler module.
  *)

  (** Fetch handler processes incoming HTTP requests.

      @param request The incoming HTTP request
      @param env The environment bindings
      @param ctx The execution context
      @return A Promise resolving to an HTTP response
  *)
  type 'env fetch_handler = Request.t -> 'env -> ExecutionContext.t -> Response.t Js.Promise.t

  (** Scheduled handler processes cron triggers.

      @param event The scheduled event with timing information
      @param env The environment bindings
      @param ctx The execution context
      @return A Promise resolving when processing is complete
  *)
  type 'env scheduled_handler = 'env ScheduledEvent.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (** Queue handler processes messages from Cloudflare Queues.

      @param batch The batch of queue messages to process
      @param env The environment bindings
      @param ctx The execution context
      @return A Promise resolving when processing is complete
  *)
  type 'env queue_handler = QueueEvent.Batch.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (** Email handler processes incoming emails via Email Routing.

      @param message The incoming email message
      @param env The environment bindings
      @param ctx The execution context
      @return A Promise resolving when processing is complete
  *)
  type 'env email_handler = EmailEvent.Message.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (** Tail handler processes execution logs from other Workers.

      @param events Array of tail items representing Worker executions
      @param env The environment bindings
      @param ctx The execution context
      @return A Promise resolving when processing is complete
  *)
  type 'env tail_handler = Handler.tail_item array -> 'env -> ExecutionContext.t -> unit Js.Promise.t

  (** Alarm handler processes Durable Object alarms.

      @param info Optional alarm information including retry count
      @return A Promise resolving when processing is complete
  *)
  type alarm_handler = Handler.alarm_info option -> unit Js.Promise.t

  (** {2 WorkerEntrypoint Class Type} *)

  (** The WorkerEntrypoint class type.

      This represents a Cloudflare WorkerEntrypoint instance that can handle
      multiple event types and expose RPC methods.
  *)
  type 'env t

  (** {2 Creating WorkerEntrypoint Instances} *)

  (** [make ?fetch ?scheduled ?queue ?email ?tail ?alarm ()] creates a WorkerEntrypoint.

      All handlers are optional - include only the ones your Worker needs.
      The resulting WorkerEntrypoint should be exported as your Worker's default export.

      Unlike the {!Handler.make} function which creates a simple object export,
      this function generates an ES6 class that extends WorkerEntrypoint, enabling
      RPC functionality and service binding support.

      @param fetch Optional fetch handler for HTTP requests
      @param scheduled Optional scheduled handler for cron triggers
      @param queue Optional queue handler for processing queue messages
      @param email Optional email handler for incoming emails
      @param tail Optional tail handler for processing execution logs
      @param alarm Optional alarm handler for Durable Object alarms
      @return A WorkerEntrypoint class instance ready to be exported as default

      Example:
      {[
        let fetch_handler request env ctx =
          Response.make_json (Js.Json.string "Hello from WorkerEntrypoint")
          |> Js.Promise.resolve

        let scheduled_handler event env ctx =
          Js.log "Cron executed via WorkerEntrypoint";
          Js.Promise.resolve ()

        let default = WorkerEntrypoint.make
          ~fetch:fetch_handler
          ~scheduled:scheduled_handler
          ()
      ]}

      {3 Generated JavaScript}

      This generates JavaScript code like:
      {v
        import { WorkerEntrypoint } from 'cloudflare:workers';

        export default class extends WorkerEntrypoint {
          async fetch(request, env, ctx) {
            return fetch_handler(request, env, ctx);
          }

          async scheduled(event, env, ctx) {
            return scheduled_handler(event, env, ctx);
          }
        }
      v}
  *)
  val make :
    ?fetch:('env fetch_handler) ->
    ?scheduled:('env scheduled_handler) ->
    ?queue:('env queue_handler) ->
    ?email:('env email_handler) ->
    ?tail:('env tail_handler) ->
    ?alarm:alarm_handler ->
    unit ->
    'env t
end
