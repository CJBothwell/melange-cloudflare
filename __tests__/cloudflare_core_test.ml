open CloudflareCore

(* Test Headers *)
let test_headers () =
  let headers = Headers.make in
  Headers.set "Content-Type" "application/json" headers;
  Headers.set "X-Custom-Header" "test-value" headers;

  let content_type = Headers.get "Content-Type" headers in
  let custom = Headers.get "X-Custom-Header" headers in

  Js.log "Headers test:";
  Js.log2 "  Content-Type:" content_type;
  Js.log2 "  X-Custom-Header:" custom;
  Js.log2 "  Has Content-Type:" (Headers.has "Content-Type" headers);
  Js.log ""

(* Test Headers.of_list *)
let test_headers_of_list () =
  let headers = Headers.of_list [
    ("Content-Type", "text/html");
    ("Cache-Control", "max-age=3600");
    ("X-Test", "value");
  ] in

  Js.log "Headers.of_list test:";
  Js.log2 "  Content-Type:" (Headers.get "Content-Type" headers);
  Js.log2 "  Cache-Control:" (Headers.get "Cache-Control" headers);
  Js.log ""

(* Test Request creation *)
let test_request () =
  let request = Request.make "https://example.com/api/data" in

  Js.log "Request test:";
  Js.log2 "  URL:" (Request.url request);
  Js.log2 "  Method:" (Request.request_method request);
  Js.log ""

(* Test Request with Cloudflare properties *)
let test_request_with_cf () =
  let cf_opts = Request.cf_properties
    ~cacheTtl:3600
    ~cacheEverything:true
    ()
  in

  let init = Request.init
    ~method_:Post
    ~cf:cf_opts
    ()
  in

  let request = Request.make_with_init "https://example.com/api/upload" init in

  Js.log "Request with CF properties test:";
  Js.log2 "  URL:" (Request.url request);
  Js.log2 "  Method:" (Request.request_method request);
  Js.log ""

(* Test Response creation *)
let test_response () =
  let init = Response.init
    ~status:200
    ~statusText:"OK"
    ()
  in

  let response = Response.make None init in

  Js.log "Response test:";
  Js.log2 "  Status:" (Response.status response);
  Js.log2 "  Status Text:" (Response.statusText response);
  Js.log2 "  OK:" (Response.ok response);
  Js.log ""

(* Test JSON Response *)
let test_json_response () =
  let json_data = Js.Json.object_ (Js.Dict.fromList [
    ("message", Js.Json.string "Hello, World!");
    ("status", Js.Json.string "success");
    ("count", Js.Json.number 42.0);
  ]) in

  let response = Response.make_json json_data in

  Js.log "JSON Response test:";
  Js.log2 "  Status:" (Response.status response);
  Js.log ""

(* Test Redirect Response *)
let test_redirect () =
  let response = Response.redirect "https://example.com/new-location" 302 in

  Js.log "Redirect test:";
  Js.log2 "  Status:" (Response.status response);
  Js.log2 "  Redirected:" (Response.redirected response);
  Js.log ""

(* Test FormData *)
let test_formdata () =
  let form = FormData.make () in
  FormData.set form "username" "alice";
  FormData.set form "email" "alice@example.com";
  FormData.append form "tags" "developer";
  FormData.append form "tags" "ocaml";

  Js.log "FormData test:";
  Js.log2 "  Has username:" (FormData.has form "username");
  Js.log2 "  Username:" (FormData.get form "username");
  Js.log2 "  Email:" (FormData.get form "email");
  Js.log ""

(* Test TextEncoder/Decoder *)
let test_text_encoding () =
  let encoder = TextEncoder.make () in
  let text = "Hello, Cloudflare Workers!" in
  let encoded = TextEncoder.encode encoder text in

  let decoder = TextDecoder.make () in
  let buffer = Js.Typed_array.Uint8Array.buffer encoded in
  let decoded = TextDecoder.decode decoder buffer in

  Js.log "Text Encoding test:";
  Js.log2 "  Original:" text;
  Js.log2 "  Encoded length:" (Js.Typed_array.Uint8Array.length encoded);
  Js.log2 "  Decoded:" decoded;
  Js.log ""

(* Test base64 encoding *)
let test_base64 () =
  let text = "Hello, World!" in
  let encoded = btoa text in
  let decoded = atob encoded in

  Js.log "Base64 test:";
  Js.log2 "  Original:" text;
  Js.log2 "  Encoded:" encoded;
  Js.log2 "  Decoded:" decoded;
  Js.log ""

(* Run all tests *)
let () =
  Js.log "\n=== CloudflareCore Tests ===\n";
  test_headers ();
  test_headers_of_list ();
  test_request ();
  test_request_with_cf ();
  test_response ();
  test_json_response ();
  test_redirect ();
  test_formdata ();
  test_text_encoding ();
  test_base64 ();
  Js.log "=== All tests completed ===\n"
