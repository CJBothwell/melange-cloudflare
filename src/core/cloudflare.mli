(** CloudflareCore - Core types and utilities for Cloudflare Workers bindings.

    This module provides the fundamental types used across all Cloudflare Workers
    APIs, including HTTP Request/Response handling, Headers, URL manipulation,
    and common data structures.

    Built on top of melange-fetch for standard Fetch API types, with extensions
    for Cloudflare-specific features.

    @author Melange Cloudflare Bindings
    @version 1.0.0
*)

(** {1 Re-exported Standard Fetch API Types} *)

(** HTTP Headers - re-exported from melange-fetch.

    The Headers interface represents HTTP headers. Headers can be constructed,
    modified, and queried. They are used in both Request and Response objects
    to manage HTTP header fields.
*)
module Headers : sig
  (** The type representing HTTP headers. *)
  type t = Fetch.Headers.t

  (** [make] creates a new empty Headers object.

      Note: This is defined as a value (not a function) because melange-fetch
      uses [@@mel.new] which doesn't require unit argument.
  *)
  val make : t

  (** [append name value t] adds a new value to an existing header or creates a new header.

      Unlike {!set}, if the header already exists, [append] will add the new value
      to the existing values rather than replacing them.

      @param name The header name (case-insensitive).
      @param value The header value to append.
      @param t The Headers object.
  *)
  val append : string -> string -> t -> unit

  (** [delete name t] removes a header from the Headers object.

      @param name The header name to remove (case-insensitive).
      @param t The Headers object.
  *)
  val delete : string -> t -> unit

  (** [get name t] retrieves the value of a header.

      @param name The header name to retrieve (case-insensitive).
      @param t The Headers object.
      @return [Some value] if the header exists, [None] otherwise.
  *)
  val get : string -> t -> string option

  (** [has name t] checks if a header exists.

      @param name The header name to check (case-insensitive).
      @param t The Headers object.
      @return [true] if the header exists, [false] otherwise.
  *)
  val has : string -> t -> bool

  (** [set name value t] sets a header to a specific value, replacing any existing value.

      @param name The header name (case-insensitive).
      @param value The new header value.
      @param t The Headers object.
  *)
  val set : string -> string -> t -> unit

  (** [of_list headers] creates a Headers object from a list of key-value pairs.

      Helper function for convenient header construction.

      @param headers A list of (name, value) tuples representing header fields.
      @return A new Headers object containing the specified headers.

      Example: [of_list [("Content-Type", "application/json"); ("X-Custom", "value")]]
  *)
  val of_list : (string * string) list -> t
end

(** {1 HTTP Methods} *)

(** HTTP request methods - re-exported from melange-fetch. *)
type request_method = Fetch.requestMethod

(** {1 Body Types} *)

(** Body initialization types - re-exported from melange-fetch.

    These types represent the various ways a request or response body
    can be initialized.
*)
type bodyInit = Fetch.bodyInit

(** ReadableStream type for streaming data. *)
type readableStream = Fetch.readableStream

(** Blob type for binary data. *)
type blob = Fetch.blob

(** FormData type for multipart form data. *)
type formData = Fetch.formData

(** ArrayBuffer type for binary data. *)
type arrayBuffer = Fetch.arrayBuffer

(** BufferSource type - either an ArrayBuffer or ArrayBufferView. *)
type bufferSource = Fetch.bufferSource

(** {1 Body Initialization} *)

(** Helper functions for creating request/response bodies.

    These functions provide type-safe ways to create body content.
    They convert various data types into the bodyInit type
    that can be used with Request.make and Response.make.
*)
module BodyInit : sig
  (** [string s] creates a body from a string.

      This is the most common way to create a body for text content.

      @param s The string content.
      @return A bodyInit that can be used with Request/Response.

      Example:
      {[
        let body = BodyInit.string "Hello, World!" in
        Response.make ~body init
      ]}
  *)
  val string : string -> bodyInit

  (** [blob b] creates a body from a Blob.

      @param b The blob containing binary data.
      @return A bodyInit that can be used with Request/Response.
  *)
  val blob : blob -> bodyInit

  (** [form_data fd] creates a body from FormData.

      Useful for multipart/form-data requests.

      @param fd The FormData object.
      @return A bodyInit that can be used with Request/Response.
  *)
  val form_data : formData -> bodyInit

  (** [buffer buf] creates a body from a BufferSource (ArrayBuffer or ArrayBufferView).

      @param buf The buffer containing binary data.
      @return A bodyInit that can be used with Request/Response.
  *)
  val buffer : bufferSource -> bodyInit

  (** [stream s] creates a body from a ReadableStream.

      Useful for streaming responses.

      @param s The readable stream.
      @return A bodyInit that can be used with Request/Response.
  *)
  val stream : readableStream -> bodyInit
end

(** The FormData interface for working with form data. *)
module FormData : sig
  (** The type representing FormData. *)
  type t = formData

  (** [make ()] creates a new empty FormData object. *)
  val make : unit -> t

  (** [append t name value] appends a new value to a field.

      @param t The FormData object.
      @param name The field name.
      @param value The field value.
  *)
  val append : t -> string -> string -> unit

  (** [delete t name] removes all values for a field.

      @param t The FormData object.
      @param name The field name to remove.
  *)
  val delete : t -> string -> unit

  (** [get t name] gets the first value for a field.

      @param t The FormData object.
      @param name The field name.
      @return [Some value] if the field exists, [None] otherwise.
  *)
  val get : t -> string -> string option

  (** [has t name] checks if a field exists.

      @param t The FormData object.
      @param name The field name to check.
      @return [true] if the field exists, [false] otherwise.
  *)
  val has : t -> string -> bool

  (** [set t name value] sets a field to a specific value.

      @param t The FormData object.
      @param name The field name.
      @param value The new field value.
  *)
  val set : t -> string -> string -> unit
end

(** {1 Cloudflare-Specific Request Extensions} *)

(** The Request interface represents an HTTP request.

    Built on top of the standard Fetch API Request type, with extensions
    for Cloudflare-specific features like cache control and image resizing.
*)
module Request : sig
  (** The type representing an HTTP request. *)
  type t = Fetch.request

  (** Redirect handling modes. *)
  type redirect =
    | Follow  (** Automatically follow redirects (default) *)
    | Error  (** Reject requests that result in redirects *)
    | Manual  (** Return redirect responses as-is *)

  (** Cloudflare-specific request properties.

      These properties control Cloudflare-specific features like caching,
      image resizing, and content processing.
  *)
  type cf_properties = {
    cacheTtl : int option;  (** Cache TTL in seconds *)
    cacheEverything : bool option;  (** Cache all content, not just static assets *)
    cacheKey : string option;  (** Custom cache key *)
    cacheTtlByStatus : (int * int) list option;  (** Status-specific cache TTLs [(status, ttl)] *)
    scrapeShield : bool option;  (** Enable scrape shield *)
    apps : bool option;  (** Enable Cloudflare Apps *)
    image : image_resizing_options option;  (** Image resizing options *)
    minify : minify_options option;  (** Minification options *)
    mirage : bool option;  (** Enable Mirage image optimization *)
    polish : polish_option option;  (** Image polish level *)
    resolveOverride : string option;  (** DNS resolution override *)
  }

  (** Image resizing options for Cloudflare's image transformation. *)
  and image_resizing_options = {
    width : int option;  (** Target width in pixels *)
    height : int option;  (** Target height in pixels *)
    fit : image_fit option;  (** How to fit the image in the dimensions *)
    gravity : image_gravity option;  (** Focus point for cropping *)
    quality : int option;  (** JPEG/WebP quality (1-100) *)
    format : image_format option;  (** Output format *)
    dpr : float option;  (** Device pixel ratio (0.1-10.0) *)
  }

  (** Image fit modes. *)
  and image_fit =
    | ScaleDown  (** Scale down if larger, never scale up *)
    | Contain  (** Preserve aspect ratio, fit within dimensions *)
    | Cover  (** Preserve aspect ratio, fill dimensions, crop if needed *)
    | Crop  (** Ignore aspect ratio, fill exactly *)
    | Pad  (** Preserve aspect ratio, pad to fill dimensions *)

  (** Image gravity for cropping. *)
  and image_gravity =
    | Auto  (** Automatically detect focus point *)
    | Left
    | Right
    | Top
    | Bottom
    | Center

  (** Image output formats. *)
  and image_format =
    | AVIF
    | WebP
    | JSON  (** Return metadata as JSON *)

  (** Minification options. *)
  and minify_options = {
    javascript : bool option;  (** Minify JavaScript *)
    css : bool option;  (** Minify CSS *)
    html : bool option;  (** Minify HTML *)
  }

  (** Image polish levels. *)
  and polish_option =
    | Off  (** Disable polish *)
    | Lossy  (** Lossy compression *)
    | Lossless  (** Lossless compression *)

  (** Request initialization options with Cloudflare extensions. *)
  type init = {
    method_ : request_method option;  (** HTTP method (default: GET) *)
    headers : Headers.t option;  (** Request headers *)
    body : bodyInit option;  (** Request body (not allowed for GET/HEAD) *)
    redirect : redirect option;  (** Redirect handling mode *)
    cf : cf_properties option;  (** Cloudflare-specific properties *)
  }

  (** [make url] creates a GET request for the given URL.

      @param url The URL to request.
      @return A new Request object.
  *)
  val make : string -> t

  (** [make_with_init url init] creates a request with specific options.

      This extends the standard Fetch API to support Cloudflare-specific
      properties in the cf field.

      @param url The URL to request.
      @param init Request initialization options including CF properties.
      @return A new Request object.
  *)
  val make_with_init : string -> init -> t

  (** [url t] gets the request URL.

      @param t The Request object.
      @return The full URL as a string.
  *)
  val url : t -> string

  (** [request_method t] gets the HTTP method.

      @param t The Request object.
      @return The HTTP method.
  *)
  val request_method : t -> request_method

  (** [headers t] gets the request headers.

      @param t The Request object.
      @return The Headers object.
  *)
  val headers : t -> Headers.t

  (** [clone t] creates a copy of the request.

      This is useful when you need to read the body multiple times,
      as bodies can only be read once.

      @param t The Request object.
      @return A new Request object with the same properties.
      @raise Js.Exn.Error if the body has already been used.
  *)
  val clone : t -> t

  (** [text t] reads the request body as text.

      @param t The Request object.
      @return A Promise that resolves to the body as a UTF-8 string.
  *)
  val text : t -> string Js.Promise.t

  (** [json t] reads the request body as JSON.

      @param t The Request object.
      @return A Promise that resolves to the parsed JSON value.
  *)
  val json : t -> Js.Json.t Js.Promise.t

  (** [arrayBuffer t] reads the request body as binary data.

      @param t The Request object.
      @return A Promise that resolves to an ArrayBuffer.
  *)
  val arrayBuffer : t -> Fetch.arrayBuffer Js.Promise.t

  (** [formData t] reads the request body as form data.

      @param t The Request object.
      @return A Promise that resolves to a FormData object.
  *)
  val formData : t -> formData Js.Promise.t

  (** [blob t] reads the request body as a Blob.

      @param t The Request object.
      @return A Promise that resolves to a Blob.
  *)
  val blob : t -> blob Js.Promise.t
end

(** {1 Cloudflare-Specific Response Extensions} *)

(** The Response interface represents an HTTP response.

    Built on top of the standard Fetch API Response type, with extensions
    for Cloudflare-specific features.
*)
module Response : sig
  (** The type representing an HTTP response. *)
  type t = Fetch.response

  (** Cloudflare-specific response properties. *)
  type cf_properties = {
    cacheStatus : cache_status option;  (** Cache hit/miss status *)
    cacheKey : string option;  (** The cache key used *)
  }

  (** Cache status values. *)
  and cache_status =
    | Hit  (** Response served from cache *)
    | Miss  (** Response not in cache *)
    | Expired  (** Cached response expired *)
    | Stale  (** Cached response is stale *)
    | Bypass  (** Cache was bypassed *)
    | Revalidated  (** Cached response was revalidated *)
    | Dynamic  (** Response is dynamic and not cached *)
    | Ignored  (** Caching was ignored *)

  (** Response initialization options. *)
  type init = {
    status : int option;  (** HTTP status code (default: 200) *)
    statusText : string option;  (** HTTP status text *)
    headers : Headers.t option;  (** Response headers *)
  }

  (** [make ?body init] creates a new Response.

      @param body The response body (optional).
      @param init Response initialization options.
      @return A new Response object.
  *)
  val make : ?body:bodyInit -> init -> t

  (** [make_json json] creates a JSON response.

      Automatically sets Content-Type to application/json and serializes
      the JSON value.

      @param json The JSON value to serialize.
      @return A new Response object with JSON body and appropriate headers.
  *)
  val make_json : Js.Json.t -> t

  (** [make_json_with_init json init] creates a JSON response with options.

      @param json The JSON value to serialize.
      @param init Response initialization options.
      @return A new Response object.
  *)
  val make_json_with_init : Js.Json.t -> init -> t

  (** [redirect url status] creates a redirect response.

      @param url The URL to redirect to.
      @param status The redirect status code (301, 302, 303, 307, or 308).
      @return A new Response object with a Location header.
      @raise Js.Exn.Error if status is not a valid redirect code.
  *)
  val redirect : string -> int -> t

  (** [error ()] creates a network error response.

      @return A Response object representing a network error.
  *)
  val error : unit -> t

  (** [status t] gets the HTTP status code.

      @param t The Response object.
      @return The status code (e.g., 200, 404).
  *)
  val status : t -> int

  (** [statusText t] gets the HTTP status text.

      @param t The Response object.
      @return The status text (e.g., "OK", "Not Found").
  *)
  val statusText : t -> string

  (** [ok t] checks if the response is successful.

      @param t The Response object.
      @return [true] if status is in the range 200-299, [false] otherwise.
  *)
  val ok : t -> bool

  (** [headers t] gets the response headers.

      @param t The Response object.
      @return The Headers object.
  *)
  val headers : t -> Headers.t

  (** [redirected t] checks if the response is the result of a redirect.

      @param t The Response object.
      @return [true] if the response resulted from a redirect, [false] otherwise.
  *)
  val redirected : t -> bool

  (** [url t] gets the final URL after redirects.

      @param t The Response object.
      @return The URL as a string.
  *)
  val url : t -> string

  (** [clone t] creates a copy of the response.

      This is useful when you need to read the body multiple times,
      as bodies can only be read once.

      @param t The Response object.
      @return A new Response object with the same properties.
      @raise Js.Exn.Error if the body has already been used.
  *)
  val clone : t -> t

  (** [text t] reads the response body as text.

      @param t The Response object.
      @return A Promise that resolves to the body as a UTF-8 string.
  *)
  val text : t -> string Js.Promise.t

  (** [json t] reads the response body as JSON.

      @param t The Response object.
      @return A Promise that resolves to the parsed JSON value.
  *)
  val json : t -> Js.Json.t Js.Promise.t

  (** [arrayBuffer t] reads the response body as binary data.

      @param t The Response object.
      @return A Promise that resolves to an ArrayBuffer.
  *)
  val arrayBuffer : t -> Fetch.arrayBuffer Js.Promise.t

  (** [formData t] reads the response body as form data.

      @param t The Response object.
      @return A Promise that resolves to a FormData object.
  *)
  val formData : t -> formData Js.Promise.t

  (** [blob t] reads the response body as a Blob.

      @param t The Response object.
      @return A Promise that resolves to a Blob.
  *)
  val blob : t -> blob Js.Promise.t
end

(** {1 Fetch API} *)

(** Fetch API functions are automatically available via [include Fetch].

    Available functions:
    - [fetch : string -> Response.t Js.Promise.t] - makes an HTTP GET request
    - [fetchWithRequest : Request.t -> Response.t Js.Promise.t] - uses a Request object
    - [fetchWithInit : string -> requestInit -> Response.t Js.Promise.t] - with standard options

    For Cloudflare-specific fetch with [cf_properties]:
    {[
      let request = Request.make_with_init url init in
      fetchWithRequest request
    ]}
*)

(** {1 Text Encoding and Decoding} *)

(** The TextEncoder interface encodes strings into UTF-8 bytes. *)
module TextEncoder : sig
  (** The type representing a TextEncoder. *)
  type t

  (** [make ()] creates a new TextEncoder. *)
  val make : unit -> t

  (** [encode t str] encodes a string into UTF-8 bytes.

      @param t The TextEncoder object.
      @param str The string to encode.
      @return A Uint8Array containing the UTF-8 bytes.
  *)
  val encode : t -> string -> Js.Typed_array.Uint8Array.t

  (** [encoding t] gets the encoding name (always "utf-8").

      @param t The TextEncoder object.
      @return The string "utf-8".
  *)
  val encoding : t -> string
end

(** The TextDecoder interface decodes bytes into strings. *)
module TextDecoder : sig
  (** The type representing a TextDecoder. *)
  type t

  (** [make ()] creates a new UTF-8 TextDecoder. *)
  val make : unit -> t

  (** [make_with_encoding encoding] creates a TextDecoder for a specific encoding.

      @param encoding The character encoding name (e.g., "utf-8", "iso-8859-1").
      @return A new TextDecoder object.
  *)
  val make_with_encoding : string -> t

  (** [decode t buffer] decodes bytes into a string.

      @param t The TextDecoder object.
      @param buffer The bytes to decode (ArrayBuffer or TypedArray).
      @return The decoded string.
  *)
  val decode : t -> Fetch.arrayBuffer -> string

  (** [encoding t] gets the encoding name.

      @param t The TextDecoder object.
      @return The encoding name.
  *)
  val encoding : t -> string
end

(** {1 Utilities} *)

(** [btoa str] encodes a string to Base64.

    @param str The string to encode (must be ASCII).
    @return The Base64-encoded string.
    @raise Js.Exn.Error if the string contains non-ASCII characters.
*)
val btoa : string -> string

(** [atob str] decodes a Base64 string.

    @param str The Base64 string to decode.
    @return The decoded string.
    @raise Js.Exn.Error if the input is not valid Base64.
*)
val atob : string -> string
