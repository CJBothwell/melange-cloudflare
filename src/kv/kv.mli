(** Cloudflare Workers KV Store Bindings.

    Workers KV is a global, low-latency key-value data store. It's optimized
    for high read volumes and provides eventual consistency across Cloudflare's
    global network.

    KV is ideal for storing configuration, user preferences, cached data, and
    other information that needs to be quickly accessible from any location.

    @author Melange Cloudflare Bindings
    @version 1.0.0
*)

open Cloudflare

(** {1 KV Namespace} *)

(** The KVNamespace type represents a Workers KV namespace.

    KV namespaces are collections of key-value pairs that are bound to your
    Worker through environment variables. Each namespace is isolated and can
    contain millions of keys.

    KV is optimized for:
    - High read volume (millions of reads per second globally)
    - Low latency (reads from the nearest Cloudflare data center)
    - Large values (up to 25 MB per value)

    KV is eventually consistent, meaning writes may take up to 60 seconds to
    propagate globally.
*)
module Namespace : sig
  (** The type representing a KV namespace. *)
  type t

  (** {2 Reading Values} *)

  (** Value types that can be returned from KV. *)
  type value_type =
    | Text  (** UTF-8 text string *)
    | Json  (** Parsed JSON value *)
    | ArrayBuffer  (** Binary data as ArrayBuffer *)
    | Stream  (** Binary data as ReadableStream *)

  (** Metadata type for values with metadata. *)
  type 'a with_metadata = {
    value : 'a;  (** The value itself *)
    metadata : Js.Json.t option;  (** Optional metadata object *)
  }

  (** [get ns key] retrieves a value as text.

      This is the most common way to read from KV. Returns the value as a
      UTF-8 string, or [None] if the key doesn't exist.

      @param ns The KV namespace.
      @param key The key to retrieve (max 512 bytes).
      @return A Promise that resolves to [Some value] or [None].

      Example:
      {[
        Js.Promise.(
          get kv "user:123:preferences"
          |> then_ (function
              | Some prefs -> (* process preferences *)
              | None -> (* use defaults *)
          )
        )
      ]}
  *)
  val get : t -> string -> string option Js.Promise.t

  (** [get_with_type ns key value_type] retrieves a value with a specific type.

      This allows you to specify how the value should be decoded:
      - [Text]: Returns a UTF-8 string
      - [Json]: Parses the value as JSON
      - [ArrayBuffer]: Returns binary data as ArrayBuffer
      - [Stream]: Returns binary data as a ReadableStream

      @param ns The KV namespace.
      @param key The key to retrieve.
      @param value_type How to decode the value.
      @return A Promise that resolves to [Some value] or [None].

      Example:
      {[
        Js.Promise.(
          get_with_type kv "app:config" Json
          |> then_ (function
              | Some json -> (* parse JSON config *)
              | None -> (* use defaults *)
          )
        )
      ]}
  *)
  val get_with_type : t -> string -> value_type -> 'a option Js.Promise.t

  (** [get_with_metadata ns key] retrieves a value along with its metadata.

      When values are stored with metadata, this retrieves both the value
      and its associated metadata object.

      @param ns The KV namespace.
      @param key The key to retrieve.
      @return A Promise that resolves to [Some {value; metadata}] or [None].

      Example:
      {[
        Js.Promise.(
          get_with_metadata kv "cached:page:home"
          |> then_ (function
              | Some {value; metadata = Some meta} ->
                  (* Check if cache is still valid using metadata *)
              | Some {value; metadata = None} ->
                  (* Value exists but has no metadata *)
              | None -> (* Key not found *)
          )
        )
      ]}
  *)
  val get_with_metadata : t -> string -> string with_metadata option Js.Promise.t

  (** [get_with_metadata_and_type ns key value_type] retrieves a typed value with metadata.

      Combines type specification and metadata retrieval.

      @param ns The KV namespace.
      @param key The key to retrieve.
      @param value_type How to decode the value.
      @return A Promise that resolves to [Some {value; metadata}] or [None].
  *)
  val get_with_metadata_and_type : t -> string -> value_type ->
    'a with_metadata option Js.Promise.t

  (** {2 Writing Values} *)

  (** Options for put operations. *)
  type put_options = {
    expiration : int option;
        (** Absolute expiration time in seconds since Unix epoch.
            After this time, the key will be automatically deleted. *)
    expirationTtl : int option;
        (** Time-to-live in seconds from now.
            The key will be deleted after this many seconds. *)
    metadata : Js.Json.t option;
        (** Optional metadata to store with the value (max 1024 bytes).
            Metadata can be any JSON-serializable value. *)
  }

  (** [put ns key value] stores a string value.

      Writes are asynchronous and may take up to 60 seconds to propagate
      globally. The promise resolves as soon as the write is accepted, not
      when it's fully propagated.

      @param ns The KV namespace.
      @param key The key to store (max 512 bytes).
      @param value The value to store (max 25 MB).
      @return A Promise that resolves when the write is accepted.

      Example:
      {[
        Js.Promise.(
          put kv "user:123:name" "Alice"
          |> then_ (fun () ->
              (* Write accepted, will propagate globally *)
              resolve ()
          )
        )
      ]}
  *)
  val put : t -> string -> string -> unit Js.Promise.t

  (** [put_with_options ns key value options] stores a value with options.

      Allows you to set expiration and metadata when writing.

      @param ns The KV namespace.
      @param key The key to store.
      @param value The value to store.
      @param options Put options (expiration, TTL, metadata).
      @return A Promise that resolves when the write is accepted.

      Example:
      {[
        Js.Promise.(
          put_with_options kv "session:abc123" session_data {
            expiration = None;
            expirationTtl = Some 3600;  (* Expire in 1 hour *)
            metadata = Some (Js.Json.object_ (Js.Dict.fromList [
              ("created", Js.Json.number (Js.Date.now ()))
            ]));
          }
          |> then_ (fun () ->
              (* Session will auto-expire in 1 hour *)
              resolve ()
          )
        )
      ]}
  *)
  val put_with_options : t -> string -> string -> put_options -> unit Js.Promise.t

  (** [put_buffer ns key buffer] stores binary data from an ArrayBuffer.

      @param ns The KV namespace.
      @param key The key to store.
      @param buffer The binary data to store.
      @return A Promise that resolves when the write is accepted.
  *)
  val put_buffer : t -> string -> Fetch.arrayBuffer -> unit Js.Promise.t

  (** [put_buffer_with_options ns key buffer options] stores binary data with options.

      @param ns The KV namespace.
      @param key The key to store.
      @param buffer The binary data to store.
      @param options Put options.
      @return A Promise that resolves when the write is accepted.
  *)
  val put_buffer_with_options : t -> string -> Fetch.arrayBuffer ->
    put_options -> unit Js.Promise.t

  (** [put_stream ns key stream] stores data from a ReadableStream.

      This is useful for streaming large values without loading them entirely
      into memory.

      @param ns The KV namespace.
      @param key The key to store.
      @param stream The stream of data to store.
      @return A Promise that resolves when the write is accepted.
  *)
  val put_stream : t -> string -> readableStream -> unit Js.Promise.t

  (** [put_stream_with_options ns key stream options] stores streamed data with options.

      @param ns The KV namespace.
      @param key The key to store.
      @param stream The stream of data to store.
      @param options Put options.
      @return A Promise that resolves when the write is accepted.
  *)
  val put_stream_with_options : t -> string -> readableStream ->
    put_options -> unit Js.Promise.t

  (** {2 Deleting Values} *)

  (** [delete ns key] deletes a key-value pair.

      Like writes, deletes are asynchronous and may take up to 60 seconds to
      propagate globally. The promise resolves as soon as the delete is accepted.

      @param ns The KV namespace.
      @param key The key to delete.
      @return A Promise that resolves when the delete is accepted.

      Example:
      {[
        Js.Promise.(
          delete kv "session:expired123"
          |> then_ (fun () ->
              (* Delete accepted, will propagate globally *)
              resolve ()
          )
        )
      ]}
  *)
  val delete : t -> string -> unit Js.Promise.t

  (** {2 Listing Keys} *)

  (** Options for list operations. *)
  type list_options = {
    limit : int option;
        (** Maximum number of keys to return (default 1000, max 1000). *)
    prefix : string option;
        (** Only return keys starting with this prefix. *)
    cursor : string option;
        (** Pagination cursor from a previous list operation. *)
  }

  (** Information about a key. *)
  type list_key = {
    name : string;  (** The key name *)
    expiration : int option;  (** Expiration time in seconds since epoch *)
    metadata : Js.Json.t option;  (** Key metadata if present *)
  }

  (** Alias for list_key - same type. *)
  type key_info = list_key

  (** List result containing keys and pagination info. *)
  type list_result = {
    keys : list_key array;  (** The keys in this page *)
    list_complete : bool;  (** [true] if this is the last page *)
    cursor : string option;  (** Cursor for fetching the next page *)
  }

  (** [list ns] lists all keys in the namespace.

      Returns up to 1000 keys. Use pagination to retrieve more.

      @param ns The KV namespace.
      @return A Promise that resolves to the list result.

      Example:
      {[
        Js.Promise.(
          list kv
          |> then_ (fun result ->
              Array.iter (fun key_info ->
                Js.log key_info.name
              ) result.keys;
              resolve ()
          )
        )
      ]}
  *)
  val list : t -> list_result Js.Promise.t

  (** [list_with_options ns options] lists keys with filtering and pagination.

      This allows you to:
      - Limit the number of keys returned
      - Filter by key prefix
      - Paginate through large result sets

      @param ns The KV namespace.
      @param options List options.
      @return A Promise that resolves to the list result.

      Example:
      {[
        (* List all keys starting with "user:" *)
        let rec list_all_users cursor acc =
          Js.Promise.(
            list_with_options kv {
              limit = Some 1000;
              prefix = Some "user:";
              cursor;
            }
            |> then_ (fun result ->
                let acc' = Array.append acc result.keys in
                if result.list_complete then
                  resolve acc'
                else
                  list_all_users result.cursor acc'
            )
          )
        in
        Js.Promise.(
          list_all_users None [||]
          |> then_ (fun all_user_keys ->
              (* Process all user keys *)
              resolve ()
          )
        )
      ]}
  *)
  val list_with_options : t -> list_options -> list_result Js.Promise.t

  (** {2 Helper Functions} *)

  (** [exists ns key] checks if a key exists.

      This is implemented as a metadata-only get operation, which is cheaper
      than fetching the full value.

      @param ns The KV namespace.
      @param key The key to check.
      @return A Promise that resolves to [true] if the key exists, [false] otherwise.
  *)
  val exists : t -> string -> bool Js.Promise.t

  (** [get_json ns key] retrieves and parses a JSON value.

      Convenience function that combines [get_with_type] with [Json] type.

      @param ns The KV namespace.
      @param key The key to retrieve.
      @return A Promise that resolves to [Some json] or [None].
  *)
  val get_json : t -> string -> Js.Json.t option Js.Promise.t

  (** [put_json ns key json] stores a JSON value.

      Automatically serializes the JSON value before storing.

      @param ns The KV namespace.
      @param key The key to store.
      @param json The JSON value to store.
      @return A Promise that resolves when the write is accepted.
  *)
  val put_json : t -> string -> Js.Json.t -> unit Js.Promise.t

  (** [put_json_with_options ns key json options] stores a JSON value with options.

      @param ns The KV namespace.
      @param key The key to store.
      @param json The JSON value to store.
      @param options Put options.
      @return A Promise that resolves when the write is accepted.
  *)
  val put_json_with_options : t -> string -> Js.Json.t -> put_options ->
    unit Js.Promise.t

  (** [get_with_cache_ttl ns key cache_ttl] retrieves a value with cache control.

      Allows you to specify how long the value should be cached on Cloudflare's
      edge before being revalidated from storage.

      @param ns The KV namespace.
      @param key The key to retrieve.
      @param cache_ttl Cache TTL in seconds.
      @return A Promise that resolves to [Some value] or [None].
  *)
  val get_with_cache_ttl : t -> string -> int -> string option Js.Promise.t
end

(** {1 Bulk Operations} *)

(** Helper module for batch operations on KV. *)
module Bulk : sig
  (** [get_multiple ns keys] retrieves multiple keys in parallel.

      This doesn't use a special API, but rather runs multiple get operations
      concurrently for better performance.

      @param ns The KV namespace.
      @param keys Array of keys to retrieve.
      @return A Promise that resolves to an array of (key, value option) pairs.

      Example:
      {[
        let keys = [|"user:1"; "user:2"; "user:3"|] in
        Js.Promise.(
          Bulk.get_multiple kv keys
          |> then_ (fun results ->
              Array.iter (fun (key, value_opt) ->
                match value_opt with
                | Some value -> Printf.printf "%s: %s\n" key value
                | None -> Printf.printf "%s: not found\n" key
              ) results;
              resolve ()
          )
        )
      ]}
  *)
  val get_multiple : Namespace.t -> string array ->
    (string * string option) array Js.Promise.t

  (** [put_multiple ns pairs] stores multiple key-value pairs in parallel.

      @param ns The KV namespace.
      @param pairs Array of (key, value) tuples to store.
      @return A Promise that resolves when all writes are accepted.
  *)
  val put_multiple : Namespace.t -> (string * string) array -> unit Js.Promise.t

  (** [delete_multiple ns keys] deletes multiple keys in parallel.

      @param ns The KV namespace.
      @param keys Array of keys to delete.
      @return A Promise that resolves when all deletes are accepted.
  *)
  val delete_multiple : Namespace.t -> string array -> unit Js.Promise.t
end

(** {1 Key Naming Patterns} *)

(** Best practices for KV key naming.

    Since KV doesn't have true hierarchies, using consistent key naming
    patterns helps organize your data and makes listing more efficient.
*)
module KeyPatterns : sig
  (** [make_user_key user_id field] creates a user-scoped key.

      Example: [make_user_key "123" "preferences"] -> "user:123:preferences"

      @param user_id The user ID.
      @param field The field name.
      @return A formatted key string.
  *)
  val make_user_key : string -> string -> string

  (** [make_cache_key resource params] creates a cache key.

      Example: [make_cache_key "page" [("url", "/home"); ("lang", "en")]]
               -> "cache:page:url=/home:lang=en"

      @param resource The resource type.
      @param params List of (name, value) parameters.
      @return A formatted cache key.
  *)
  val make_cache_key : string -> (string * string) list -> string

  (** [make_timestamped_key prefix timestamp] creates a time-ordered key.

      Useful for storing time-series data where you want keys to sort
      chronologically.

      @param prefix The key prefix.
      @param timestamp Unix timestamp in seconds.
      @return A formatted key with timestamp.
  *)
  val make_timestamped_key : string -> float -> string

  (** [parse_user_key key] extracts user_id and field from a user key.

      @param key The key to parse (e.g., "user:123:preferences").
      @return [Some (user_id, field)] if the key matches the pattern, [None] otherwise.
  *)
  val parse_user_key : string -> (string * string) option
end

(** {1 Error Handling} *)

(** KV error types. *)
module Error : sig
  (** KV error categories. *)
  type error_type =
    | KeyTooLarge  (** Key exceeds 512 bytes *)
    | ValueTooLarge  (** Value exceeds 25 MB *)
    | MetadataTooLarge  (** Metadata exceeds 1024 bytes *)
    | InternalError  (** Internal KV error *)
    | NetworkError  (** Network or connection error *)
    | InvalidOperation  (** Invalid operation (e.g., bad parameters) *)

  (** The type representing a KV error. *)
  type t = {
    error_type : error_type;  (** The category of error *)
    message : string;  (** The error message *)
  }

  (** [message err] gets the error message.

      @param err The error.
      @return The error message string.
  *)
  val message : t -> string

  (** [error_type err] gets the error type.

      @param err The error.
      @return The error category.
  *)
  val error_type : t -> error_type

  (** [to_string err] converts the error to a string.

      @param err The error.
      @return A string representation of the error.
  *)
  val to_string : t -> string
end

(** {1 Accessing KV from Environment} *)

(** [from_env env binding_name] retrieves a KV namespace from environment bindings.

    KV namespaces are configured in your wrangler.toml and bound to your Worker
    through the environment. This function retrieves the namespace by its binding name.

    @param env The Worker environment object.
    @param binding_name The name of the KV binding (as configured in wrangler.toml).
    @return [Some namespace] if the binding exists, [None] otherwise.

    Example:
    {[
      (* In wrangler.toml:
         [[kv_namespaces]]
         binding = "MY_KV"
         id = "..." *)

      let fetch request env ctx =
        match from_env env "MY_KV" with
        | Some kv ->
            Js.Promise.(
              Namespace.get kv "config"
              |> then_ (fun value ->
                  (* Process value *)
                  resolve (Response.make_text "OK")
              )
            )
        | None ->
            Response.make_json
              (Js.Json.string "KV namespace not configured")
              (Some { status = Some 500; statusText = None; headers = None; cf = None })
            |> Js.Promise.resolve
    ]}
*)
val from_env : 'env -> string -> Namespace.t option
