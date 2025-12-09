(** Basic Cloudflare Worker Example

    This example demonstrates:
    - Modern Workers Handler API (export default pattern)
    - Request/Response handling
    - URL routing and path matching
    - Different content types (JSON, HTML, text)
    - HTTP method handling
    - Custom headers and status codes
    - Request inspection
*)

open Cloudflare
open Workers

(* Our environment type - empty for this basic example *)
type env = unit

(* Helper to create JSON responses *)
let json_response data status =
  let init = { Response.status = Some status; statusText = None; headers = None } in
  Response.make_json_with_init data init

(* Helper to create text responses *)
let text_response text status =
  let headers = Headers.of_list [
    ("Content-Type", "text/plain; charset=utf-8");
  ] in
  let init = { Response.status = Some status; statusText = None; headers = Some headers } in
  let body = BodyInit.string text in
  Response.make ~body init

(* Helper to create HTML responses *)
let html_response html status =
  let headers = Headers.of_list [
    ("Content-Type", "text/html; charset=utf-8");
  ] in
  let init = { Response.status = Some status; statusText = None; headers = Some headers } in
  let body = BodyInit.string html in
  Response.make ~body init

(* Route: GET /api/hello - Returns JSON greeting *)
let handle_api_hello _request =
  let json = Js.Json.object_ (Js.Dict.fromList [
    ("message", Js.Json.string "Hello from Melange + Cloudflare Workers!");
    ("timestamp", Js.Json.number (Js.Date.now ()));
    ("status", Js.Json.string "success");
  ]) in
  json_response json 200

(* Route: POST /api/echo - Echoes back the request body *)
let handle_api_echo request =
  let open Js.Promise in
  Request.text request
  |> then_ (fun body ->
    let json = Js.Json.object_ (Js.Dict.fromList [
      ("echo", Js.Json.string body);
      ("length", Js.Json.number (float_of_int (String.length body)));
    ]) in
    resolve (json_response json 200)
  )

(* Route: GET /api/headers - Returns request headers as JSON *)
let handle_api_headers request =
  let headers = Request.headers request in
  let headers_dict = Js.Dict.empty () in

  (* Note: In a real implementation, you'd iterate over headers *)
  (* For now, we'll just return some common headers *)
  let user_agent = Headers.get "User-Agent" headers in
  (match user_agent with
   | Some ua -> Js.Dict.set headers_dict "user-agent" (Js.Json.string ua)
   | None -> ());

  let content_type = Headers.get "Content-Type" headers in
  (match content_type with
   | Some ct -> Js.Dict.set headers_dict "content-type" (Js.Json.string ct)
   | None -> ());

  let json = Js.Json.object_ (Js.Dict.fromList [
    ("headers", Js.Json.object_ headers_dict);
  ]) in
  json_response json 200

(* Route: GET /api/methods - Shows HTTP method info *)
let handle_api_methods request =
  let method_ = Request.request_method request in
  let method_str = match method_ with
    | Get -> "GET"
    | Post -> "POST"
    | Put -> "PUT"
    | Delete -> "DELETE"
    | Head -> "HEAD"
    | Options -> "OPTIONS"
    | Patch -> "PATCH"
    | Connect -> "CONNECT"
    | Trace -> "TRACE"
    | Other s -> s
  in

  let json = Js.Json.object_ (Js.Dict.fromList [
    ("method", Js.Json.string method_str);
    ("allowed_methods", Js.Json.array [|
      Js.Json.string "GET";
      Js.Json.string "POST";
      Js.Json.string "PUT";
      Js.Json.string "DELETE";
      Js.Json.string "PATCH";
    |]);
  ]) in
  json_response json 200

(* Route: GET /redirect - Tests redirect functionality *)
let handle_redirect () =
  Response.redirect "https://example.com" 302

(* Route: GET /custom-headers - Response with custom headers *)
let handle_custom_headers () =
  let headers = Headers.of_list [
    ("Content-Type", "text/plain");
    ("X-Custom-Header", "Melange-Rocks");
    ("X-Powered-By", "OCaml + Melange");
    ("X-Example-Version", "1.0.0");
  ] in
  let init = { Response.status = Some 200; statusText = None; headers = Some headers } in
  let body = BodyInit.string "Check the response headers!" in
  Response.make ~body init

(* Default route - Home page with HTML *)
let handle_home request =
  let url = Request.url request in
  let method_ = Request.request_method request in
  let method_str = match method_ with
    | Get -> "GET"
    | Post -> "POST"
    | Put -> "PUT"
    | Delete -> "DELETE"
    | Head -> "HEAD"
    | Options -> "OPTIONS"
    | Patch -> "PATCH"
    | Connect -> "CONNECT"
    | Trace -> "TRACE"
    | Other s -> s
  in

  let html = {|<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Melange Cloudflare Worker - Basic Example</title>
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
        max-width: 900px;
        margin: 0 auto;
        padding: 40px 20px;
        line-height: 1.6;
        color: #333;
      }
      h1 { color: #f38020; margin-bottom: 10px; }
      h2 { color: #555; margin-top: 30px; margin-bottom: 15px; border-bottom: 2px solid #f38020; padding-bottom: 5px; }
      h3 { color: #666; margin-top: 20px; margin-bottom: 10px; }
      code {
        background: #f4f4f4;
        padding: 2px 6px;
        border-radius: 3px;
        font-family: 'Monaco', 'Menlo', monospace;
        font-size: 0.9em;
      }
      pre {
        background: #f4f4f4;
        padding: 15px;
        border-radius: 5px;
        overflow-x: auto;
        margin: 10px 0;
      }
      pre code { background: none; padding: 0; }
      ul { margin-left: 20px; margin-bottom: 15px; }
      li { margin-bottom: 8px; }
      a { color: #f38020; text-decoration: none; }
      a:hover { text-decoration: underline; }
      .info-box {
        background: #e8f4f8;
        border-left: 4px solid #2196F3;
        padding: 15px;
        margin: 20px 0;
      }
      .endpoint {
        background: #f9f9f9;
        border: 1px solid #ddd;
        padding: 10px;
        margin: 10px 0;
        border-radius: 4px;
      }
      .method {
        display: inline-block;
        padding: 2px 8px;
        border-radius: 3px;
        font-weight: bold;
        font-size: 0.85em;
        margin-right: 8px;
      }
      .method-get { background: #61affe; color: white; }
      .method-post { background: #49cc90; color: white; }
    </style>
  </head>
  <body>
    <h1>🚀 Melange + Cloudflare Workers</h1>
    <p><strong>Basic Worker Example</strong></p>

    <div class="info-box">
      <p><strong>Current Request:</strong></p>
      <p>URL: <code>|} ^ url ^ {|</code></p>
      <p>Method: <code>|} ^ method_str ^ {|</code></p>
    </div>

    <h2>📚 About This Example</h2>
    <p>
      This is a basic Cloudflare Worker written in <strong>OCaml</strong> and compiled to
      JavaScript using <strong>Melange</strong>. It demonstrates core functionality like
      request handling, routing, and responses.
    </p>

    <h2>🔗 Available Endpoints</h2>

    <h3>JSON API Endpoints</h3>

    <div class="endpoint">
      <span class="method method-get">GET</span>
      <a href="/api/hello">/api/hello</a>
      <p>Returns a JSON greeting with timestamp</p>
    </div>

    <div class="endpoint">
      <span class="method method-post">POST</span>
      <code>/api/echo</code>
      <p>Echoes back the request body as JSON</p>
      <pre><code>curl -X POST https://your-worker.dev/api/echo -d "Hello, World!"</code></pre>
    </div>

    <div class="endpoint">
      <span class="method method-get">GET</span>
      <a href="/api/headers">/api/headers</a>
      <p>Returns request headers as JSON</p>
    </div>

    <div class="endpoint">
      <span class="method method-get">GET</span>
      <a href="/api/methods">/api/methods</a>
      <p>Shows HTTP method information</p>
    </div>

    <h3>Other Endpoints</h3>

    <div class="endpoint">
      <span class="method method-get">GET</span>
      <a href="/redirect">/redirect</a>
      <p>Tests HTTP redirect (302 to example.com)</p>
    </div>

    <div class="endpoint">
      <span class="method method-get">GET</span>
      <a href="/custom-headers">/custom-headers</a>
      <p>Response with custom HTTP headers</p>
    </div>

    <h2>💡 Features Demonstrated</h2>
    <ul>
      <li>Request/Response handling using Cloudflare Workers API</li>
      <li>URL-based routing</li>
      <li>Multiple content types (JSON, HTML, text)</li>
      <li>HTTP method detection</li>
      <li>Custom headers</li>
      <li>Request body parsing</li>
      <li>HTTP redirects</li>
      <li>Type-safe OCaml code compiled to JavaScript</li>
    </ul>

    <h2>🛠 Technology Stack</h2>
    <ul>
      <li><strong>OCaml</strong> - Functional programming language</li>
      <li><strong>Melange</strong> - OCaml to JavaScript compiler</li>
      <li><strong>Cloudflare Workers</strong> - Edge computing platform</li>
      <li><strong>melange-cloudflare</strong> - Type-safe bindings</li>
    </ul>

    <h2>📖 Learn More</h2>
    <ul>
      <li><a href="https://melange.re" target="_blank">Melange Documentation</a></li>
      <li><a href="https://developers.cloudflare.com/workers" target="_blank">Cloudflare Workers Docs</a></li>
      <li><a href="https://ocaml.org" target="_blank">OCaml Language</a></li>
    </ul>
  </body>
</html>
|} in
  html_response html 200

(* Main request router *)
let handle_request (request : Request.t) (_env : env) (_ctx : ExecutionContext.t) =
  let open Js.Promise in

  let url = Request.url request in
  let method_ = Request.request_method request in

  (* Log the request *)
  Js.log2 "Request:" url;

  (* Route based on URL path *)
  if Js.String.includes ~search:"/api/hello" url then
    resolve (handle_api_hello request)

  else if Js.String.includes ~search:"/api/echo" url then
    if method_ = Post then
      handle_api_echo request
    else
      resolve (text_response "Method Not Allowed. Use POST." 405)

  else if Js.String.includes ~search:"/api/headers" url then
    resolve (handle_api_headers request)

  else if Js.String.includes ~search:"/api/methods" url then
    resolve (handle_api_methods request)

  else if Js.String.includes ~search:"/redirect" url then
    resolve (handle_redirect ())

  else if Js.String.includes ~search:"/custom-headers" url then
    resolve (handle_custom_headers ())

  else
    (* Default: home page *)
    resolve (handle_home request)

(* Export the handler using the modern Workers API *)
let default = Handler.make ~fetch:handle_request ()
