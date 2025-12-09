(** CloudflareCore - Core types and utilities for Cloudflare Workers bindings.

    This module provides the fundamental types used across all Cloudflare Workers
    APIs, including HTTP Request/Response handling, Headers, URL manipulation,
    and common data structures.

    Built on top of melange-fetch for standard Fetch API types, with extensions
    for Cloudflare-specific features.
*)

(** {1 Re-exported Standard Fetch API Types} *)

(* Include all standard Fetch API types and functions *)
include Fetch

(** HTTP Headers - extended from melange-fetch with helper functions. *)
module Headers = struct
  include Fetch.Headers

  (* Add convenience helper for creating headers from a list *)
  let of_list headers =
    let h = make in
    List.iter (fun (name, value) -> set name value h) headers;
    h
end

(** {1 Body Initialization} *)

module BodyInit = struct
  (* Re-export Fetch.BodyInit functions for convenience *)
  let string = Fetch.BodyInit.make
  let blob = Fetch.BodyInit.makeWithBlob
  let form_data = Fetch.BodyInit.makeWithFormData
  let buffer = Fetch.BodyInit.makeWithBufferSource

  (* ReadableStream is a valid bodyInit but melange-fetch doesn't provide a constructor.
     We use %identity like melange-fetch does for other BodyInit constructors. *)
  external stream : readableStream -> bodyInit = "%identity"
end

(** {1 Convenient Type Aliases} *)

(** HTTP request methods - alias for better naming. *)
type request_method = requestMethod

(** The FormData interface for working with form data. *)
module FormData = struct
  type t = formData

  external make : unit -> t = "FormData" [@@mel.new]

  external append : t -> string -> string -> unit = "append" [@@mel.send]

  external delete : t -> string -> unit = "delete" [@@mel.send]

  external get : t -> string -> string option = "get"
    [@@mel.send] [@@mel.return nullable]

  external has : t -> string -> bool = "has" [@@mel.send]

  external set : t -> string -> string -> unit = "set" [@@mel.send]
end

(** {1 Cloudflare-Specific Request Extensions} *)

(** The Request interface represents an HTTP request. *)
module Request = struct
  include Fetch.Request

  (** Redirect handling modes. *)
  type redirect =
    | Follow [@mel.as "follow"]
    | Error [@mel.as "error"]
    | Manual [@mel.as "manual"]

  (** Image fit modes for resizing. *)
  type image_fit =
    | ScaleDown [@mel.as "scale-down"]
    | Contain [@mel.as "contain"]
    | Cover [@mel.as "cover"]
    | Crop [@mel.as "crop"]
    | Pad [@mel.as "pad"]

  (** Image gravity modes for cropping/positioning. *)
  type image_gravity =
    | Auto [@mel.as "auto"]
    | Left [@mel.as "left"]
    | Right [@mel.as "right"]
    | Top [@mel.as "top"]
    | Bottom [@mel.as "bottom"]
    | Center [@mel.as "center"]

  (** Image output formats. *)
  type image_format =
    | AVIF [@mel.as "avif"]
    | WebP [@mel.as "webp"]
    | JSON [@mel.as "json"]

  (** Polish compression modes. *)
  type polish_option =
    | Off [@mel.as "off"]
    | Lossy [@mel.as "lossy"]
    | Lossless [@mel.as "lossless"]

  (** Image resizing options. *)
  type image_resizing_options = {
    width : int option; [@mel.optional]
    height : int option; [@mel.optional]
    fit : image_fit option; [@mel.optional]
    gravity : image_gravity option; [@mel.optional]
    quality : int option; [@mel.optional]
    format : image_format option; [@mel.optional]
    dpr : float option; [@mel.optional]
  }
  [@@deriving jsProperties]

  (** Minification options. *)
  type minify_options = {
    javascript : bool option; [@mel.optional]
    css : bool option; [@mel.optional]
    html : bool option; [@mel.optional]
  }
  [@@deriving jsProperties]

  (** Cloudflare-specific request properties. *)
  type cf_properties = {
    cacheTtl : int option; [@mel.optional]
    cacheEverything : bool option; [@mel.optional]
    cacheKey : string option; [@mel.optional]
    cacheTtlByStatus : (int * int) list option; [@mel.optional]
    scrapeShield : bool option; [@mel.optional]
    apps : bool option; [@mel.optional]
    image : image_resizing_options option; [@mel.optional]
    minify : minify_options option; [@mel.optional]
    mirage : bool option; [@mel.optional]
    polish : polish_option option; [@mel.optional]
    resolveOverride : string option; [@mel.optional]
  }
  [@@deriving jsProperties]

  (** Request initialization options with Cloudflare extensions. *)
  type init = {
    method_ : request_method option;
    headers : Headers.t option;
    body : bodyInit option;
    redirect : redirect option;
    cf : cf_properties option;
  }

  (* Internal type for JavaScript object *)
  type init_js

  (* Direct binding to Request constructor *)
  external makeWithInit_ : string -> init_js -> t = "Request" [@@mel.new]

  (* Helper to build JavaScript init object *)
  external make_init_js :
    method_:request_method option ->
    headers:Headers.t option ->
    body:bodyInit option ->
    redirect:redirect option ->
    cf:cf_properties option ->
    init_js = "" [@@mel.obj]

  (* Cloudflare-specific constructor with cf properties *)
  let make_with_init url options =
    let js_init = make_init_js
      ~method_:options.method_
      ~headers:options.headers
      ~body:options.body
      ~redirect:options.redirect
      ~cf:options.cf
    in
    makeWithInit_ url js_init

  (* Alias for better OCaml naming convention *)
  let request_method = method_

  (* Alias for clone using makeWithRequest *)
  let clone = makeWithRequest
end

(** {1 Cloudflare-Specific Response Extensions} *)

(** The Response interface represents an HTTP response. *)
module Response = struct
  include Fetch.Response

  (** Cache status values from Cloudflare. *)
  type cache_status =
    | Hit
    | Miss
    | Expired
    | Stale
    | Bypass
    | Revalidated
    | Dynamic
    | Ignored

  (** Cloudflare-specific response properties. *)
  type cf_properties = {
    cacheStatus : cache_status option; [@mel.optional]
    cacheKey : string option; [@mel.optional]
  }
  [@@deriving jsProperties]

  (** Response initialization options. *)
  type init = {
    status : int option;
    statusText : string option;
    headers : Headers.t option;
  }

  (* Internal type for JavaScript object *)
  type init_js

  (* Direct bindings to Response constructor - JavaScript allows optional body *)
  external makeWithInit_ : bodyInit -> init_js -> t = "Response" [@@mel.new]
  external makeWithInitOnly_ : init_js -> t = "Response" [@@mel.new]

  (* Helper to build JavaScript init object *)
  external make_init_js :
    status:int option ->
    statusText:string option ->
    headers:Headers.t option ->
    init_js = "" [@@mel.obj]

  (* Static methods for Response construction *)
  external redirect : string -> int -> t = "redirect"
    [@@mel.scope "Response"]

  external error : unit -> t = "error"
    [@@mel.scope "Response"]

  external json_static : Js.Json.t -> t = "json"
    [@@mel.scope "Response"]

  external json_static_with_init : Js.Json.t -> init_js -> t = "json"
    [@@mel.scope "Response"]

  (* Cloudflare-specific Response constructors *)
  let make ?body options =
    let js_init = make_init_js
      ~status:options.status
      ~statusText:options.statusText
      ~headers:options.headers
    in
    match body with
    | Some b -> makeWithInit_ b js_init
    | None -> makeWithInitOnly_ js_init

  let make_json json_data =
    json_static json_data

  let make_json_with_init json_data options =
    let js_init = make_init_js
      ~status:options.status
      ~statusText:options.statusText
      ~headers:options.headers
    in
    json_static_with_init json_data js_init
end

(** {1 Fetch API} *)

(* Note: fetch, fetchWithRequest, and fetchWithInit are automatically available
   via `include Fetch` at the top level. No need to re-implement.

   For Cloudflare-specific fetch with cf_properties:
   1. Create a Request with Request.make_with_init
   2. Use fetchWithRequest
*)

(** {1 Text Encoding and Decoding} *)

module TextEncoder = struct
  type t

  external make : unit -> t = "TextEncoder" [@@mel.new]

  external encode : t -> string -> Js.Typed_array.Uint8Array.t = "encode" [@@mel.send]

  external encoding : t -> string = "encoding" [@@mel.get]
end

module TextDecoder = struct
  type t

  external make : unit -> t = "TextDecoder" [@@mel.new]

  external make_with_encoding : string -> t = "TextDecoder" [@@mel.new]

  external decode : t -> Fetch.arrayBuffer -> string = "decode" [@@mel.send]

  external encoding : t -> string = "encoding" [@@mel.get]
end

(** {1 Utilities} *)

external btoa : string -> string = "btoa"

external atob : string -> string = "atob"
