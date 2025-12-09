(** Cloudflare R2 Object Storage Bindings.

    R2 is Cloudflare's S3-compatible object storage service with no egress fees.
    This module provides type-safe bindings for storing and retrieving objects,
    managing metadata, and performing multipart uploads.

    R2 is ideal for:
    - Storing large files (images, videos, documents)
    - Serving static assets
    - Archival storage
    - Backup and disaster recovery

    @author Melange Cloudflare Bindings
    @version 1.0.0
*)

open Cloudflare

(** {1 R2 Bucket} *)

(** The R2Bucket type represents an R2 storage bucket.

    R2 buckets are bound to your Worker through environment variables.
    Each bucket can contain an unlimited number of objects up to 5 TB each.

    R2 provides strong consistency - writes are immediately readable from
    all locations.
*)
module rec Bucket : sig
  (** The type representing an R2 bucket. *)
  type t

  (** {2 Object Operations} *)

  (** [head bucket key] retrieves object metadata without downloading the object.

      This is useful for checking if an object exists and getting its size,
      etag, and custom metadata without the cost of downloading the full object.

      @param bucket The R2 bucket.
      @param key The object key (path).
      @return A Promise that resolves to [Some object] if found, [None] otherwise.

      Example:
      {[
        Js.Promise.(
          head bucket "images/photo.jpg"
          |> then_ (function
              | Some obj ->
                  let size = R2Object.size obj in
                  Printf.printf "Image size: %d bytes\n" size;
                  resolve ()
              | None ->
                  Printf.printf "Image not found\n";
                  resolve ()
          )
        )
      ]}
  *)
  val head : t -> string -> R2Object.t option Js.Promise.t

  (** [get bucket key] retrieves an object with its body.

      Downloads the complete object including its metadata and content.

      @param bucket The R2 bucket.
      @param key The object key (path).
      @return A Promise that resolves to [Some object_body] if found, [None] otherwise.

      Example:
      {[
        Js.Promise.(
          get bucket "config.json"
          |> then_ (function
              | Some obj_body ->
                  R2ObjectBody.text obj_body
                  |> then_ (fun text ->
                      (* Process text content *)
                      resolve ()
                  )
              | None ->
                  (* Object not found *)
                  resolve ()
          )
        )
      ]}
  *)
  val get : t -> string -> R2ObjectBody.t option Js.Promise.t

  (** Range specification for partial downloads. *)
  type range = {
    offset : int;  (** Starting byte offset *)
    length : int option;  (** Number of bytes to read (None = to end) *)
  }

  (** Conditional request options. *)
  type conditional = {
    etagMatches : string option;
        (** Only return if ETag matches. *)
    etagDoesNotMatch : string option;
        (** Only return if ETag doesn't match. *)
    uploadedBefore : Js.Date.t option;
        (** Only return if uploaded before this date. *)
    uploadedAfter : Js.Date.t option;
        (** Only return if uploaded after this date. *)
  }

  (** Options for get operations. *)
  type get_options = {
    onlyIf : conditional option;
        (** Conditional request (only return if conditions match). *)
    range : range option;
        (** Range request (only return part of the object). *)
  }

  (** [get_with_options bucket key options] retrieves an object with specific options.

      Allows you to specify conditional requests, range requests, and more.

      @param bucket The R2 bucket.
      @param key The object key.
      @param options Get options (onlyIf, range, etc.).
      @return A Promise that resolves to [Some object_body] if found, [None] otherwise.
  *)
  val get_with_options : t -> string -> get_options -> R2ObjectBody.t option Js.Promise.t

  (** [put bucket key value] uploads an object.

      Stores data in R2. The key can contain forward slashes to simulate
      a directory structure.

      @param bucket The R2 bucket.
      @param key The object key (path).
      @param value The data to store (string, ArrayBuffer, Blob, or ReadableStream).
      @return A Promise that resolves to the created object metadata.

      Example:
      {[
        let data = "Hello, R2!" in
        Js.Promise.(
          put bucket "greeting.txt" (String data)
          |> then_ (fun obj ->
              let etag = R2Object.etag obj in
              Printf.printf "Uploaded with ETag: %s\n" etag;
              resolve ()
          )
        )
      ]}
  *)
  val put : t -> string -> bodyInit -> R2Object.t Js.Promise.t

  (** Storage class for objects. *)
  type storage_class =
    | Standard  (** Standard storage (default) *)
    | InfrequentAccess  (** Infrequent access storage (lower cost) *)

  (** HTTP metadata for objects. *)
  type http_metadata = {
    contentType : string option;
        (** MIME type (e.g., "image/jpeg", "application/json"). *)
    contentLanguage : string option;
        (** Content language (e.g., "en-US"). *)
    contentDisposition : string option;
        (** Content disposition (e.g., "attachment; filename=file.pdf"). *)
    contentEncoding : string option;
        (** Content encoding (e.g., "gzip"). *)
    cacheControl : string option;
        (** Cache control directive (e.g., "max-age=3600"). *)
    cacheExpiry : Js.Date.t option;
        (** Absolute cache expiration time. *)
  }

  (** Options for put operations. *)
  type put_options = {
    httpMetadata : http_metadata option;
        (** HTTP metadata (Content-Type, Cache-Control, etc.). *)
    customMetadata : Js.Json.t Js.Dict.t option;
        (** Custom metadata key-value pairs (max 2KB total). *)
    onlyIf : conditional option;
        (** Conditional upload (only upload if conditions match). *)
    storageClass : storage_class option;
        (** Storage class for the object. *)
  }

  (** [put_with_options bucket key value options] uploads an object with options.

      Allows you to set custom metadata, content type, cache control headers,
      and conditional uploads.

      @param bucket The R2 bucket.
      @param key The object key.
      @param value The data to store.
      @param options Put options (metadata, httpMetadata, etc.).
      @return A Promise that resolves to the created object metadata.

      Example:
      {[
        Js.Promise.(
          put_with_options bucket "image.jpg" (Blob image_blob) {
            httpMetadata = Some {
              contentType = Some "image/jpeg";
              contentLanguage = None;
              contentDisposition = None;
              contentEncoding = None;
              cacheControl = Some "public, max-age=31536000";
              cacheExpiry = None;
            };
            customMetadata = Some (Js.Dict.fromList [
              ("uploader", Js.Json.string "user123");
              ("original-name", Js.Json.string "vacation.jpg");
            ]);
            onlyIf = None;
            storageClass = None;
          }
          |> then_ (fun obj ->
              (* Object uploaded with metadata *)
              resolve ()
          )
        )
      ]}
  *)
  val put_with_options : t -> string -> bodyInit -> put_options -> R2Object.t Js.Promise.t

  (** [delete bucket key] deletes an object.

      Permanently removes an object from the bucket. This operation cannot
      be undone.

      @param bucket The R2 bucket.
      @param key The object key to delete.
      @return A Promise that resolves when the object is deleted.

      Example:
      {[
        Js.Promise.(
          delete bucket "temp/file.txt"
          |> then_ (fun () ->
              (* Object deleted *)
              resolve ()
          )
        )
      ]}
  *)
  val delete : t -> string -> unit Js.Promise.t

  (** [delete_multiple bucket keys] deletes multiple objects.

      More efficient than deleting objects one by one. Can delete up to
      1000 objects per call.

      @param bucket The R2 bucket.
      @param keys Array of object keys to delete (max 1000).
      @return A Promise that resolves when all objects are deleted.

      Example:
      {[
        let keys = [|"temp/file1.txt"; "temp/file2.txt"; "temp/file3.txt"|] in
        Js.Promise.(
          delete_multiple bucket keys
          |> then_ (fun () ->
              (* All objects deleted *)
              resolve ()
          )
        )
      ]}
  *)
  val delete_multiple : t -> string array -> unit Js.Promise.t

  (** {2 Listing Objects} *)

  (** Fields to include in list results. *)
  type include_fields =
    | HttpMetadata  (** Include HTTP metadata *)
    | CustomMetadata  (** Include custom metadata *)
    | All  (** Include all metadata *)

  (** Options for list operations. *)
  type list_options = {
    limit : int option;
        (** Maximum number of objects to return (max 1000, default 1000). *)
    prefix : string option;
        (** Only return objects with keys starting with this prefix. *)
    cursor : string option;
        (** Pagination cursor from a previous list operation. *)
    delimiter : string option;
        (** Delimiter for grouping keys (typically "/"). *)
    startAfter : string option;
        (** Only return objects with keys lexicographically after this key. *)
    include_ : include_fields option;
        (** Which fields to include in the response. *)
  }

  (** List result containing objects and pagination info. *)
  type list_result = {
    objects : R2Object.t array;  (** The objects in this page *)
    truncated : bool;  (** [true] if there are more results *)
    cursor : string option;  (** Cursor for fetching the next page *)
    delimitedPrefixes : string array;
        (** Common prefixes when using a delimiter (like subdirectories) *)
  }

  (** [list bucket] lists objects in the bucket.

      Returns up to 1000 objects. Use pagination to retrieve more.

      @param bucket The R2 bucket.
      @return A Promise that resolves to the list result.

      Example:
      {[
        Js.Promise.(
          list bucket
          |> then_ (fun result ->
              Array.iter (fun obj ->
                let key = R2Object.key obj in
                let size = R2Object.size obj in
                Printf.printf "%s: %d bytes\n" key size
              ) result.objects;
              resolve ()
          )
        )
      ]}
  *)
  val list : t -> list_result Js.Promise.t

  (** [list_with_options bucket options] lists objects with filtering and pagination.

      This allows you to:
      - Limit the number of objects returned
      - Filter by key prefix
      - Paginate through large result sets
      - Group keys by common prefixes (like listing directories)

      @param bucket The R2 bucket.
      @param options List options.
      @return A Promise that resolves to the list result.

      Example:
      {[
        (* List all objects in "images/" prefix *)
        let rec list_all_images cursor acc =
          Js.Promise.(
            list_with_options bucket {
              limit = Some 1000;
              prefix = Some "images/";
              cursor;
              delimiter = None;
              startAfter = None;
              include_ = None;
            }
            |> then_ (fun result ->
                let acc' = Array.append acc result.objects in
                if result.truncated then
                  list_all_images result.cursor acc'
                else
                  resolve acc'
            )
          )
        in
        Js.Promise.(
          list_all_images None [||]
          |> then_ (fun all_images ->
              Printf.printf "Found %d images\n" (Array.length all_images);
              resolve ()
          )
        )
      ]}
  *)
  val list_with_options : t -> list_options -> list_result Js.Promise.t

  (** {2 Multipart Upload} *)

  (** [createMultipartUpload bucket key] initiates a multipart upload.

      Multipart uploads allow you to upload large objects (>100MB) in parts.
      This is more reliable for large files as you can retry individual parts
      if they fail.

      @param bucket The R2 bucket.
      @param key The object key.
      @return A Promise that resolves to a multipart upload object.

      Example:
      {[
        Js.Promise.(
          createMultipartUpload bucket "large-file.zip"
          |> then_ (fun upload ->
              (* Upload parts *)
              completeMultipartUpload bucket upload
          )
          |> then_ (fun _ ->
              (* Upload complete *)
              resolve ()
          )
        )
      ]}
  *)
  val createMultipartUpload : t -> string -> MultipartUpload.t Js.Promise.t

  (** [createMultipartUpload_with_options bucket key options] initiates a multipart upload with options.

      @param bucket The R2 bucket.
      @param key The object key.
      @param options Put options (metadata, httpMetadata, etc.).
      @return A Promise that resolves to a multipart upload object.
  *)
  val createMultipartUpload_with_options : t -> string -> put_options ->
    MultipartUpload.t Js.Promise.t

  (** [resumeMultipartUpload bucket key upload_id] resumes an existing multipart upload.

      If a multipart upload was interrupted, you can resume it using its upload ID.

      @param bucket The R2 bucket.
      @param key The object key.
      @param upload_id The upload ID from the original createMultipartUpload.
      @return A multipart upload object.
  *)
  val resumeMultipartUpload : t -> string -> string -> MultipartUpload.t

  (** [completeMultipartUpload bucket upload] completes a multipart upload.

      After all parts are uploaded, this combines them into a single object.

      @param bucket The R2 bucket.
      @param upload The multipart upload object.
      @return A Promise that resolves to the created object metadata.
  *)
  val completeMultipartUpload : t -> MultipartUpload.t -> R2Object.t Js.Promise.t

  (** [abortMultipartUpload bucket upload] aborts a multipart upload.

      Cancels the upload and deletes all uploaded parts.

      @param bucket The R2 bucket.
      @param upload The multipart upload object.
      @return A Promise that resolves when the upload is aborted.
  *)
  val abortMultipartUpload : t -> MultipartUpload.t -> unit Js.Promise.t
end

(** {1 R2 Objects} *)

(** Metadata about an R2 object (without body). *)
and R2Object : sig
  (** The type representing R2 object metadata. *)
  type t

  (** [key obj] gets the object's key (path).

      @param obj The R2 object.
      @return The object key.
  *)
  val key : t -> string

  (** [version obj] gets the object's version ID.

      @param obj The R2 object.
      @return The version ID.
  *)
  val version : t -> string

  (** [size obj] gets the object's size in bytes.

      @param obj The R2 object.
      @return The size in bytes.
  *)
  val size : t -> int

  (** [etag obj] gets the object's ETag.

      The ETag is a hash of the object's contents. It changes whenever
      the object is modified.

      @param obj The R2 object.
      @return The ETag string.
  *)
  val etag : t -> string

  (** [httpEtag obj] gets the HTTP-formatted ETag (with quotes).

      @param obj The R2 object.
      @return The ETag in HTTP format (e.g., "abc123").
  *)
  val httpEtag : t -> string

  (** [uploaded obj] gets the upload timestamp.

      @param obj The R2 object.
      @return The date when the object was uploaded.
  *)
  val uploaded : t -> Js.Date.t

  (** [httpMetadata obj] gets the HTTP metadata.

      @param obj The R2 object.
      @return The HTTP metadata (Content-Type, Cache-Control, etc.).
  *)
  val httpMetadata : t -> Bucket.http_metadata

  (** [customMetadata obj] gets the custom metadata.

      @param obj The R2 object.
      @return A dictionary of custom metadata key-value pairs.
  *)
  val customMetadata : t -> Js.Json.t Js.Dict.t

  (** [range obj] gets the range if this is a partial object.

      When an object is retrieved with a range request, this indicates
      which portion of the object was returned.

      @param obj The R2 object.
      @return [Some range] if this is a partial object, [None] otherwise.
  *)
  val range : t -> Bucket.range option

  (** [storageClass obj] gets the storage class.

      @param obj The R2 object.
      @return The storage class.
  *)
  val storageClass : t -> Bucket.storage_class

  (** [writeHttpMetadata obj response] writes HTTP metadata to a Response.

      Convenience function to apply the object's HTTP metadata to a Response,
      setting Content-Type, Cache-Control, etc.

      @param obj The R2 object.
      @param response The Response to modify.
      @return The Response with updated headers.
  *)
  val writeHttpMetadata : t -> Response.t -> Response.t
end

(** An R2 object with its body content. *)
and R2ObjectBody : sig
  (** The type representing an R2 object with body. *)
  type t

  (** R2ObjectBody inherits all R2Object methods (key, version, size, etag, etc.)
      Please refer to R2Object documentation for these methods. *)

  (** [body obj] gets the object body as a ReadableStream.

      @param obj The R2 object body.
      @return The body as a stream.
  *)
  val body : t -> readableStream

  (** [bodyUsed obj] checks if the body has been read.

      @param obj The R2 object body.
      @return [true] if the body has been consumed, [false] otherwise.
  *)
  val bodyUsed : t -> bool

  (** [arrayBuffer obj] reads the body as an ArrayBuffer.

      @param obj The R2 object body.
      @return A Promise that resolves to the binary content.
  *)
  val arrayBuffer : t -> Fetch.arrayBuffer Js.Promise.t

  (** [text obj] reads the body as text.

      @param obj The R2 object body.
      @return A Promise that resolves to the text content.
  *)
  val text : t -> string Js.Promise.t

  (** [json obj] reads the body as JSON.

      @param obj The R2 object body.
      @return A Promise that resolves to the parsed JSON.
  *)
  val json : t -> Js.Json.t Js.Promise.t

  (** [blob obj] reads the body as a Blob.

      @param obj The R2 object body.
      @return A Promise that resolves to a Blob.
  *)
  val blob : t -> blob Js.Promise.t
end

(** {1 Multipart Upload} *)

(** A multipart upload for uploading large objects in parts. *)
and MultipartUpload : sig
  (** The type representing a multipart upload. *)
  type t

  (** [key upload] gets the object key.

      @param upload The multipart upload.
      @return The object key.
  *)
  val key : t -> string

  (** [uploadId upload] gets the upload ID.

      This ID can be used to resume the upload later.

      @param upload The multipart upload.
      @return The upload ID.
  *)
  val uploadId : t -> string

  (** [uploadPart upload part_number body] uploads a part.

      Parts must be at least 5MB except for the last part. Part numbers
      must be between 1 and 10,000.

      @param upload The multipart upload.
      @param part_number The part number (1-10,000).
      @param body The part data.
      @return A Promise that resolves to the uploaded part metadata.

      Example:
      {[
        Js.Promise.(
          uploadPart upload 1 (String data1)
          |> then_ (fun part1 ->
              uploadPart upload 2 (String data2)
          )
          |> then_ (fun part2 ->
              (* Continue uploading parts... *)
              resolve ()
          )
        )
      ]}
  *)
  val uploadPart : t -> int -> bodyInit -> UploadedPart.t Js.Promise.t

  (** [abort upload] aborts the multipart upload.

      @param upload The multipart upload.
      @return A Promise that resolves when the upload is aborted.
  *)
  val abort : t -> unit Js.Promise.t

  (** [complete upload] completes the multipart upload.

      @param upload The multipart upload.
      @return A Promise that resolves to the created object.
  *)
  val complete : t -> R2Object.t Js.Promise.t
end

(** Metadata about an uploaded part. *)
and UploadedPart : sig
  (** The type representing an uploaded part. *)
  type t

  (** [partNumber part] gets the part number.

      @param part The uploaded part.
      @return The part number.
  *)
  val partNumber : t -> int

  (** [etag part] gets the part's ETag.

      @param part The uploaded part.
      @return The ETag.
  *)
  val etag : t -> string
end

(** {1 Helper Functions} *)

(** [copy_object bucket from_key to_key] copies an object within a bucket.

    This is implemented as a get followed by a put, but preserves metadata.

    @param bucket The R2 bucket.
    @param from_key The source object key.
    @param to_key The destination object key.
    @return A Promise that resolves to the copied object metadata.
*)
val copy_object : Bucket.t -> string -> string -> R2Object.t Js.Promise.t

(** [move_object bucket from_key to_key] moves an object within a bucket.

    Implemented as a copy followed by a delete.

    @param bucket The R2 bucket.
    @param from_key The source object key.
    @param to_key The destination object key.
    @return A Promise that resolves to the moved object metadata.
*)
val move_object : Bucket.t -> string -> string -> R2Object.t Js.Promise.t

(** [generate_presigned_url bucket key expiration] generates a presigned URL.

    Note: R2 presigned URLs are generated on the Cloudflare side, not in Workers.
    This is a placeholder for when the feature is available.

    @param bucket The R2 bucket.
    @param key The object key.
    @param expiration URL expiration time in seconds.
    @return A Promise that resolves to the presigned URL.
*)
val generate_presigned_url : Bucket.t -> string -> int -> string Js.Promise.t

(** {1 Error Handling} *)

(** R2 error types. *)
module Error : sig
  (** R2 error categories. *)
  type error_type =
    | ObjectNotFound  (** The object does not exist *)
    | BucketNotFound  (** The bucket does not exist *)
    | PreconditionFailed  (** Conditional request precondition failed *)
    | InvalidObjectKey  (** Invalid object key *)
    | EntityTooLarge  (** Object exceeds size limit *)
    | InternalError  (** Internal R2 error *)
    | NetworkError  (** Network or connection error *)
    | InvalidOperation  (** Invalid operation *)

  (** The type representing an R2 error. *)
  type t = {
    error_type : error_type;  (** The category of error *)
    message : string;  (** The error message *)
    key : string option;  (** The object key if applicable *)
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

  (** [key err] gets the object key if applicable.

      @param err The error.
      @return [Some key] if the error relates to a specific object, [None] otherwise.
  *)
  val key : t -> string option

  (** [to_string err] converts the error to a string.

      @param err The error.
      @return A string representation of the error.
  *)
  val to_string : t -> string
end

(** {1 Accessing R2 from Environment} *)

(** [from_env env binding_name] retrieves an R2 bucket from environment bindings.

    R2 buckets are configured in your wrangler.toml and bound to your Worker
    through the environment. This function retrieves the bucket by its binding name.

    @param env The Worker environment object.
    @param binding_name The name of the R2 binding (as configured in wrangler.toml).
    @return [Some bucket] if the binding exists, [None] otherwise.

    Example:
    {[
      (* In wrangler.toml:
         [[r2_buckets]]
         binding = "MY_BUCKET"
         bucket_name = "my-bucket" *)

      let fetch request env ctx =
        match from_env env "MY_BUCKET" with
        | Some bucket ->
            Js.Promise.(
              Bucket.get bucket "file.txt"
              |> then_ (function
                  | Some obj ->
                      R2ObjectBody.text obj
                      |> then_ (fun text ->
                          Response.make_ok (String text) None
                          |> resolve
                      )
                  | None ->
                      Response.make None (Some {
                        status = Some 404;
                        statusText = Some "Not Found";
                        headers = None;
                        cf = None;
                      })
                      |> resolve
              )
            )
        | None ->
            Response.make_json
              (Js.Json.string "R2 bucket not configured")
              (Some { status = Some 500; statusText = None; headers = None; cf = None })
            |> Js.Promise.resolve
    ]}
*)
val from_env : 'env -> string -> Bucket.t option
