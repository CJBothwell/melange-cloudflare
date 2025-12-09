open Cloudflare

(** {1 KV Namespace} *)

module Namespace = struct
  type t

  (* Value types *)
  type value_type =
    | Text
    | Json
    | ArrayBuffer
    | Stream

  let value_type_to_string = function
    | Text -> "text"
    | Json -> "json"
    | ArrayBuffer -> "arrayBuffer"
    | Stream -> "stream"

  (* Metadata wrapper *)
  type 'a with_metadata = {
    value : 'a;
    metadata : Js.Json.t option;
  }

  (* Get options *)
  type get_options_js
  external make_get_options : ?cacheTtl:int -> ?_type:string -> unit -> get_options_js = "" [@@mel.obj]

  (* {2 Reading Values} *)

  (* Basic get - returns string *)
  external get_internal : t -> string -> string Js.Nullable.t Js.Promise.t = "get" [@@mel.send]

  let get ns key =
    let open Js.Promise in
    get_internal ns key
    |> then_ (fun result -> resolve (Js.Nullable.toOption result))

  (* Get with type *)
  external get_with_type_internal : t -> string -> string -> 'a Js.Nullable.t Js.Promise.t = "get" [@@mel.send]

  let get_with_type ns key value_type =
    let open Js.Promise in
    let type_str = value_type_to_string value_type in
    get_with_type_internal ns key type_str
    |> then_ (fun result -> resolve (Js.Nullable.toOption result))

  (* Get with options *)
  external get_with_options_internal : t -> string -> get_options_js -> 'a Js.Nullable.t Js.Promise.t = "get" [@@mel.send]

  let get_with_options ns key ~cache_ttl =
    let open Js.Promise in
    let options = make_get_options ~cacheTtl:cache_ttl () in
    get_with_options_internal ns key options
    |> then_ (fun result -> resolve (Js.Nullable.toOption result))

  let get_with_type_and_options ns key value_type ~cache_ttl =
    let open Js.Promise in
    let type_str = value_type_to_string value_type in
    let options = make_get_options ~cacheTtl:cache_ttl ~_type:type_str () in
    get_with_options_internal ns key options
    |> then_ (fun result -> resolve (Js.Nullable.toOption result))

  (* Get with metadata *)
  type 'a with_metadata_js
  external metadata_value : 'a with_metadata_js -> 'a Js.Nullable.t = "value" [@@mel.get]
  external metadata_metadata : 'a with_metadata_js -> Js.Json.t Js.Nullable.t = "metadata" [@@mel.get]

  external get_with_metadata_internal : t -> string -> 'a with_metadata_js Js.Nullable.t Js.Promise.t =
    "getWithMetadata" [@@mel.send]

  let get_with_metadata ns key =
    let open Js.Promise in
    get_with_metadata_internal ns key
    |> then_ (fun result ->
      match Js.Nullable.toOption result with
      | None -> resolve None
      | Some obj ->
          let value = Js.Nullable.toOption (metadata_value obj) in
          let metadata = Js.Nullable.toOption (metadata_metadata obj) in
          match value with
          | None -> resolve None
          | Some v -> resolve (Some { value = v; metadata })
    )

  external get_with_metadata_and_type_internal : t -> string -> string -> 'a with_metadata_js Js.Nullable.t Js.Promise.t =
    "getWithMetadata" [@@mel.send]

  let get_with_metadata_and_type ns key value_type =
    let open Js.Promise in
    let type_str = value_type_to_string value_type in
    get_with_metadata_and_type_internal ns key type_str
    |> then_ (fun result ->
      match Js.Nullable.toOption result with
      | None -> resolve None
      | Some obj ->
          let value = Js.Nullable.toOption (metadata_value obj) in
          let metadata = Js.Nullable.toOption (metadata_metadata obj) in
          match value with
          | None -> resolve None
          | Some v -> resolve (Some { value = v; metadata })
    )

  (* {2 Writing Values} *)

  type put_options = {
    expiration : int option;
    expirationTtl : int option;
    metadata : Js.Json.t option;
  }

  type put_options_js
  external make_put_options :
    ?expiration:int ->
    ?expirationTtl:int ->
    ?metadata:Js.Json.t ->
    unit ->
    put_options_js = "" [@@mel.obj]

  (* Basic put *)
  external put : t -> string -> string -> unit Js.Promise.t = "put" [@@mel.send]

  (* Put with options *)
  external put_with_options_internal : t -> string -> string -> put_options_js -> unit Js.Promise.t =
    "put" [@@mel.send]

  let put_with_options ns key value options =
    let js_options = make_put_options
      ?expiration:options.expiration
      ?expirationTtl:options.expirationTtl
      ?metadata:options.metadata
      ()
    in
    put_with_options_internal ns key value js_options

  (* Put buffer *)
  external put_buffer : t -> string -> Fetch.arrayBuffer -> unit Js.Promise.t = "put" [@@mel.send]

  external put_buffer_with_options_internal : t -> string -> Fetch.arrayBuffer -> put_options_js -> unit Js.Promise.t =
    "put" [@@mel.send]

  let put_buffer_with_options ns key buffer options =
    let js_options = make_put_options
      ?expiration:options.expiration
      ?expirationTtl:options.expirationTtl
      ?metadata:options.metadata
      ()
    in
    put_buffer_with_options_internal ns key buffer js_options

  (* Put stream *)
  external put_stream : t -> string -> readableStream -> unit Js.Promise.t = "put" [@@mel.send]

  external put_stream_with_options_internal : t -> string -> readableStream -> put_options_js -> unit Js.Promise.t =
    "put" [@@mel.send]

  let put_stream_with_options ns key stream options =
    let js_options = make_put_options
      ?expiration:options.expiration
      ?expirationTtl:options.expirationTtl
      ?metadata:options.metadata
      ()
    in
    put_stream_with_options_internal ns key stream js_options

  (* {2 Deleting Values} *)

  external delete : t -> string -> unit Js.Promise.t = "delete" [@@mel.send]

  (* {2 Listing Keys} *)

  type list_options = {
    limit : int option;
    prefix : string option;
    cursor : string option;
  }

  type list_options_js
  external make_list_options :
    ?limit:int ->
    ?prefix:string ->
    ?cursor:string ->
    unit ->
    list_options_js = "" [@@mel.obj]

  type list_key = {
    name : string;
    expiration : int option;
    metadata : Js.Json.t option;
  }

  type list_result = {
    keys : list_key array;
    list_complete : bool;
    cursor : string option;
  }

  type list_result_js
  external list_keys_js : list_result_js -> list_key array = "keys" [@@mel.get]
  external list_complete_js : list_result_js -> bool = "list_complete" [@@mel.get]
  external list_cursor_js : list_result_js -> string Js.Nullable.t = "cursor" [@@mel.get]

  external list_internal : t -> list_options_js -> list_result_js Js.Promise.t = "list" [@@mel.send]

  let list_with_options ns options =
    let open Js.Promise in
    let js_options = make_list_options
      ?limit:options.limit
      ?prefix:options.prefix
      ?cursor:options.cursor
      ()
    in
    list_internal ns js_options
    |> then_ (fun result ->
      let keys = list_keys_js result in
      let list_complete = list_complete_js result in
      let cursor = Js.Nullable.toOption (list_cursor_js result) in
      resolve { keys; list_complete; cursor }
    )

  let list ns =
    list_with_options ns { limit = None; prefix = None; cursor = None }

  let list_all = list

  type key_info = list_key

  (* Convenience helpers *)
  let exists ns key =
    let open Js.Promise in
    get ns key
    |> then_ (fun result ->
      resolve (match result with Some _ -> true | None -> false)
    )

  let get_json ns key =
    get_with_type ns key Json

  let put_json ns key json =
    let json_str = Js.Json.stringify json in
    put ns key json_str

  let put_json_with_options ns key json options =
    let json_str = Js.Json.stringify json in
    put_with_options ns key json_str options

  let get_with_cache_ttl ns key cache_ttl =
    get_with_options ns key ~cache_ttl
end

(** {1 Bulk Operations} *)

module Bulk = struct
  let get_multiple ns keys =
    let open Js.Promise in
    let promises = Array.map (fun key ->
      Namespace.get ns key
      |> then_ (fun value -> resolve (key, value))
    ) keys in
    all promises
    |> then_ (fun results -> resolve results)

  let put_multiple ns pairs =
    let open Js.Promise in
    let promises = Array.map (fun (key, value) ->
      Namespace.put ns key value
    ) pairs in
    all promises
    |> then_ (fun _ -> resolve ())

  let delete_multiple ns keys =
    let open Js.Promise in
    let promises = Array.map (fun key ->
      Namespace.delete ns key
    ) keys in
    all promises
    |> then_ (fun _ -> resolve ())
end

(** {1 Key Naming Patterns} *)

module KeyPatterns = struct
  let make_hierarchical parts =
    String.concat ":" parts

  let make_user_key user_id field =
    "user:" ^ user_id ^ ":" ^ field

  let make_session_key session_id =
    "session:" ^ session_id

  let make_cache_key resource params =
    let param_str = String.concat ":" (List.map (fun (k, v) -> k ^ "=" ^ v) params) in
    if param_str = "" then
      "cache:" ^ resource
    else
      "cache:" ^ resource ^ ":" ^ param_str

  let make_timestamped_key prefix timestamp =
    prefix ^ ":" ^ string_of_float timestamp

  let parse_user_key key =
    (* Split by ":" and check if it matches "user:id:field" pattern *)
    let parts = Js.String.split ~sep:":" key in
    if Array.length parts = 3 && parts.(0) = "user" then
      Some (parts.(1), parts.(2))
    else
      None
end

(** {1 Error Handling} *)

module Error = struct
  type error_type =
    | KeyTooLarge
    | ValueTooLarge
    | MetadataTooLarge
    | InternalError
    | NetworkError
    | InvalidOperation

  type t = {
    error_type : error_type;
    message : string;
  }

  let error_type_to_string = function
    | KeyTooLarge -> "KEY_TOO_LARGE"
    | ValueTooLarge -> "VALUE_TOO_LARGE"
    | MetadataTooLarge -> "METADATA_TOO_LARGE"
    | InternalError -> "INTERNAL_ERROR"
    | NetworkError -> "NETWORK_ERROR"
    | InvalidOperation -> "INVALID_OPERATION"

  let make error_type message =
    { error_type; message }

  let message err = err.message

  let error_type err = err.error_type

  let to_string err =
    let type_str = error_type_to_string err.error_type in
    type_str ^ ": " ^ err.message
end

(** {1 Accessing KV from Environment} *)

external from_env : 'env -> string -> Namespace.t option = "get"
  [@@mel.send] [@@mel.return nullable] [@@mel.scope "Object"]

(* Helper that's safer - doesn't use Obj.magic *)
let from_env (env : 'env) (binding_name : string) : Namespace.t option =
  let dict = (Obj.magic env : Namespace.t Js.Dict.t) in
  Js.Dict.get dict binding_name
