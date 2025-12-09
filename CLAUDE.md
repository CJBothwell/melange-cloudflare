# Melange Cloudflare Workers Bindings - Development Guide

This document contains key learnings and decisions made during the development of the melange-cloudflare library.

## Project Overview

**Goal**: Create type-safe OCaml/Melange bindings for Cloudflare Workers APIs, including:
- Core Workers runtime (fetch events, execution context)
- D1 (SQLite database)
- KV (key-value store)
- R2 (object storage)
- Durable Objects

**Architecture**: Built on top of `melange-fetch` for standard Fetch API types, with extensions for Cloudflare-specific features.

## Key Decisions

### 1. Hybrid Approach with melange-fetch

**Decision**: Use `melange-fetch` as the foundation rather than implementing everything from scratch.

**Rationale**:
- ✅ Don't reinvent the wheel for standard HTTP types (Request, Response, Headers)
- ✅ Leverage battle-tested Fetch API bindings
- ✅ Focus development effort on Cloudflare-specific features
- ✅ Better interoperability with other Melange libraries
- ✅ Less maintenance burden

**Implementation Pattern - Using `include` for Extension**:
```ocaml
(* Re-export standard types *)
type request_method = Fetch.requestMethod
type bodyInit = Fetch.bodyInit

(* Extend existing modules using include *)
module Headers = struct
  include Fetch.Headers  (* Get all Fetch.Headers functions *)

  (* Add convenience helpers *)
  let of_list headers =
    let h = make in
    List.iter (fun (name, value) -> set name value h) headers;
    h
end

(* Extend with Cloudflare-specific features *)
module Request = struct
  include Fetch.Request  (* Get all standard Request functions *)

  type cf_properties = {
    cacheTtl : int option;
    cacheEverything : bool option;
    image : image_resizing_options option;
    (* ... *)
  }

  type init = {
    method_ : request_method option;
    headers : Headers.t option;
    body : bodyInit option;
    cf : cf_properties option;  (* Cloudflare extension *)
  }

  (* Add Cloudflare-specific constructor *)
  let make_with_init url init = ...

  (* Provide convenient aliases *)
  let request_method = method_  (* Better OCaml naming *)
  let clone = makeWithRequest  (* Clone using existing function *)
end

module Response = struct
  include Fetch.Response  (* Get all standard Response functions *)

  (* Add Cloudflare-specific constructors *)
  let make body init = ...
  let make_json json = ...
  let redirect url status = ...
end
```

### 2. OCaml Naming Conventions

**Decision**: Follow standard OCaml conventions, not JavaScript conventions.

**Rules**:
- **Modules**: `PascalCase` (e.g., `Headers`, `Request`, `DurableObject`)
- **Functions**: `snake_case` (e.g., `make_with_init`, `get_env_var`, `fetch_with_init`)
- **Types**: `snake_case` (e.g., `request_method`, `cf_properties`, `durable_object_id`)
- **Variant constructors**: `PascalCase` (e.g., `Get`, `Post`, `Follow`, `Error`)
- **Record fields**: `snake_case` (e.g., `cache_ttl`, `cache_key`)

**JavaScript Interop**: Use Melange attributes to map between OCaml and JavaScript names:

```ocaml
type cf_properties = {
  cache_ttl : int option; [@mel.as "cacheTtl"]
  cache_everything : bool option; [@mel.as "cacheEverything"]
  cache_key : string option; [@mel.as "cacheKey"]
}
```

**Keyword Avoidance**: Use trailing underscore for OCaml keywords:
```ocaml
type init = {
  method_ : request_method option; [@mel.as "method"]
}
```

### 3. melange-fetch Parameter Order

**Discovery**: melange-fetch uses a specific parameter order for methods.

**Convention**: Parameters come **before** the object (via `[@mel.this]`):
```ocaml
(* melange-fetch style *)
external set : string -> string -> (t[@mel.this]) -> unit = "set" [@@mel.send]

(* Usage *)
Headers.set "Content-Type" "application/json" headers
```

**Our wrapper maintains this order**:
```ocaml
module Headers = struct
  let set name value t =
    Fetch.Headers.set name value t
end
```

### 4. Headers.make - Value vs Function

**Discovery**: melange-fetch defines `make` as a value, not a function.

```ocaml
external make : t = "Headers" [@@mel.new]
```

**Explanation**: When using `[@@mel.new]`, Melange automatically generates `new Headers()` even though the OCaml type is just `t`. No `unit` parameter needed.

**Usage**:
```ocaml
let h = Headers.make  (* Not Headers.make () *)
```

### 5. Request.clone

**Discovery**: melange-fetch doesn't have a `clone` method.

**Solution**: Use `makeWithRequest` to clone:
```ocaml
let clone t =
  Fetch.Request.makeWithRequest t
```

## Melange Attributes Reference

Essential attributes for JavaScript interop:

### Constructor Bindings
```ocaml
external make : t = "Headers" [@@mel.new]
(* Generates: new Headers() *)

external make_with_encoding : string -> t = "TextDecoder" [@@mel.new]
(* Generates: new TextDecoder(encoding) *)
```

### Method Bindings
```ocaml
external append : string -> string -> t -> unit = "append" [@@mel.send]
(* Generates: t.append(arg1, arg2) *)
```

### Property Access
```ocaml
external status : t -> int = "status" [@@mel.get]
(* Generates: t.status *)

external set_status : t -> int -> unit = "status" [@@mel.set]
(* Generates: t.status = value *)
```

### Global Values
```ocaml
external btoa : string -> string = "btoa" [@@mel.val]
(* Generates: btoa(str) *)

external randomUUID : unit -> string = "randomUUID"
  [@@mel.scope "crypto"] [@@mel.val]
(* Generates: crypto.randomUUID() *)
```

### Static Methods
```ocaml
external redirect : string -> int -> t = "redirect"
  [@@mel.scope "Response"] [@@mel.val]
(* Generates: Response.redirect(url, status) *)
```

### Field Name Mapping
```ocaml
type init = {
  cache_ttl : int option; [@mel.as "cacheTtl"]
  cache_everything : bool option; [@mel.as "cacheEverything"]
}
```

## Project Structure

```
melange-cloudflare/
├── src/
│   ├── core/           # CloudflareCore - Common types (Request, Response, Headers)
│   │   ├── CloudflareCore.mli
│   │   ├── CloudflareCore.ml
│   │   └── dune
│   ├── workers/        # Cloudflare - Workers runtime (fetch events, execution context)
│   │   ├── Cloudflare.mli
│   │   ├── Cloudflare.ml
│   │   └── dune
│   ├── d1/             # CloudflareD1 - D1 database bindings
│   │   ├── CloudflareD1.mli
│   │   └── dune
│   ├── kv/             # CloudflareKV - KV store bindings
│   │   ├── CloudflareKV.mli
│   │   └── dune
│   └── r2/             # CloudflareR2 - R2 object storage bindings
│       ├── CloudflareR2.mli
│       └── dune
├── dune-project
└── melange-cloudflare.opam
```

### Library Dependencies

```dune
(library
  (name cloudflare_core)
  (public_name melange-cloudflare.core)
  (libraries melange-fetch)          ; Core depends on melange-fetch
  (modes melange)
  (preprocess (pps melange.ppx)))

(library
  (name cloudflare_workers)
  (public_name melange-cloudflare.workers)
  (libraries cloudflare_core)        ; Workers depends on core
  (modes melange)
  (preprocess (pps melange.ppx)))
```

## Testing Strategy

**Options Evaluated**:
1. **melange-jest** - JavaScript test runner (recommended for bindings)
2. **ppx_inline_test** - OCaml inline tests (good for pure logic)

**Recommendation**: Use **melange-jest** for testing Cloudflare Workers bindings because:
- Tests run in JavaScript environment (where Workers run)
- Excellent Promise/async support
- Mock support for Fetch API
- Standard practice for JavaScript libraries

**Setup**:
```bash
opam install melange-jest
npm install --save-dev jest
```

**Test Example**:
```ocaml
(* __tests__/headers_test.ml *)
open Jest
open CloudflareCore

let () =
  describe "Headers" (fun () ->
    test "can create and set headers" (fun () ->
      let headers = Headers.make in
      Headers.set "Content-Type" "application/json" headers;

      let value = Headers.get "Content-Type" headers in
      Expect.(expect value |> toEqual (Some "application/json"))
    )
  )
```

## Common Patterns

### 1. Converting OCaml Records to JavaScript Objects

**Challenge**: Need to convert OCaml records to JavaScript objects with proper field names.

**Solution**: Use `[%mel.obj]` with `[@mel.as]` attributes:
```ocaml
type init = {
  method_ : request_method option; [@mel.as "method"]
  headers : Headers.t option;
  cf : cf_properties option;
}

let make_with_init url init =
  (* TODO: Convert init to JS object *)
  let js_init = [%mel.obj {
    method = init.method_;
    headers = init.headers;
    cf = init.cf;
  }] in
  (* Call JavaScript constructor *)
  Request.makeWithInit url js_init
```

### 2. Handling Optional Fields

**Pattern**: Only include fields in JS object if they're `Some`:
```ocaml
let convert_options opts =
  let obj = Js.Obj.empty () in
  (match opts.cacheTtl with
   | Some ttl -> Js.Obj.set obj "cacheTtl" ttl
   | None -> ());
  obj
```

### 3. Event Handlers

**Challenge**: Register JavaScript event listeners from OCaml.

**Pattern**:
```ocaml
type 'env handler = Request.t -> 'env -> ExecutionContext.t -> Response.t Js.Promise.t

external addEventListener : string -> ('a -> unit) -> unit = "addEventListener"
  [@@mel.val]

let on_fetch (handler : 'env handler) =
  addEventListener "fetch" (fun event ->
    (* Extract request, env, ctx from event *)
    (* Call handler *)
    (* Call event.respondWith *)
  )
```

## Implementation Status

### CloudflareCore.ml

**Completed** (delegates to melange-fetch):
- ✅ Headers module
- ✅ Request basic operations
- ✅ Response basic operations
- ✅ fetch and fetch_with_request
- ✅ TextEncoder and TextDecoder
- ✅ btoa/atob utilities

**TODO**:
- ⚠️ FormData module
- ⚠️ Request.make_with_init (cf_properties conversion)
- ⚠️ Response.make, make_json, make_json_with_init
- ⚠️ Response.redirect and error (static methods)
- ⚠️ fetch_with_init

### Cloudflare.ml

**Completed**:
- ✅ ExecutionContext
- ✅ ScheduledEvent getters
- ✅ QueueEvent and EmailEvent structures
- ✅ Cache API
- ✅ Crypto API
- ✅ HTMLRewriter element methods
- ✅ WebSocket operations
- ✅ DurableObject modules

**TODO**:
- ⚠️ **FetchEvent.on_fetch** (CRITICAL - main entry point)
- ⚠️ ScheduledEvent.on_scheduled
- ⚠️ QueueEvent.on_queue
- ⚠️ EmailEvent.on_email
- ⚠️ HTMLRewriter.on and onDocument
- ⚠️ WebSocketPair.make
- ⚠️ Crypto.Subtle.digest_string
- ⚠️ get_env_var (dynamic property access)

## Resources

### Documentation
- **Melange**: https://melange.re
- **melange-fetch**: https://github.com/melange-community/melange-fetch
- **Cloudflare Workers**: https://developers.cloudflare.com/workers/
- **Fetch API**: https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API

### OCaml/Melange Conventions
- **Real World OCaml**: https://dev.realworldocaml.org/
- **OCaml Style Guide**: http://ocaml.org/learn/tutorials/guidelines.html

### Testing
- **melange-jest**: https://github.com/melange-community/melange-jest
- **Jest**: https://jestjs.io/

## Critical Lessons Learned

### Interface-First Development

**Problem**: When implementing large modules (like KV with 500+ lines), it's easy for the `.ml` implementation to drift from the `.mli` interface, leading to type mismatches, missing functions, and inconsistent signatures.

**Solution**: Always follow this workflow:

1. **Start with the Interface (.mli)**
   - Design the complete API surface first
   - Document expected types, functions, and their signatures
   - This is your contract

2. **Implement Incrementally**
   - Implement one module/section at a time
   - Build frequently (`dune build`) to catch mismatches early
   - Don't add large amounts of code without building

3. **Keep Interface and Implementation in Sync**
   - If you change function signatures in `.ml`, update `.mli` immediately
   - If you add/remove error types or variants, update both files
   - Don't let them drift apart

4. **Build Often**
   - After every major function or type: `dune build`
   - Catch type mismatches before they compound
   - Small fixes are easier than large refactors

**Example of What Goes Wrong**:
```ocaml
(* .mli has this *)
type error_type =
  | KeyTooLarge
  | ValueTooLarge
  | InternalError

(* But .ml has this - different constructors! *)
type error_type =
  | KeyNotFound
  | KeyTooLarge
  | ValueTooLarge
  | InvalidKey
  | UnknownError
```

**Red Flags**:
- ❌ Implementing 300+ lines without a single build
- ❌ Adding multiple modules at once without testing each
- ❌ Changing function signatures without checking the interface
- ❌ Copy-pasting similar functions without verifying signatures

**Best Practices**:
- ✅ Build after implementing each function or small module
- ✅ Read compiler errors carefully - they tell you exactly what's wrong
- ✅ When interface says function takes `t -> result`, don't implement `t -> options -> result`
- ✅ Keep type definitions identical between `.ml` and `.mli`
- ✅ Start simple, add complexity incrementally with builds in between

### Modern Workers Handler API

**Implementation**: Successfully created variadic optional parameter pattern using `[@@mel.obj]` for modern ES6 module exports:

```ocaml
module Handler = struct
  type 'env fetch_handler = Request.t -> 'env -> ExecutionContext.t -> Response.t Js.Promise.t
  type 'env scheduled_handler = ScheduledEvent.t -> 'env -> ExecutionContext.t -> unit Js.Promise.t
  (* ... other handlers ... *)

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

(* Usage *)
let default = Handler.make ~fetch:handle_request ()
```

This generates clean JavaScript: `export default { fetch: handle_request }`

**Deprecated**: Old `addEventListener` pattern - added TODO comments suggesting users migrate to Handler API.

### Avoiding Obj.magic

**Problem**: Using `Obj.magic` for type conversions is unsafe and shouldn't be in user-facing APIs.

**Solution**: Created `BodyInit` module using `%identity` for type-safe conversions:

```ocaml
module BodyInit = struct
  let string = Fetch.BodyInit.make
  let blob = Fetch.BodyInit.makeWithBlob
  let form_data = Fetch.BodyInit.makeWithFormData
  let buffer = Fetch.BodyInit.makeWithBufferSource

  (* Use %identity like melange-fetch does *)
  external stream : readableStream -> bodyInit = "%identity"
end

(* Usage - no Obj.magic needed *)
let body = BodyInit.string "Hello, World!" in
Response.make ~body init
```

**Principle**: Follow the same patterns that `melange-fetch` uses - they're battle-tested and safe.

### WorkerEntrypoint Class Extension

**Challenge**: Cloudflare's WorkerEntrypoint requires extending a JavaScript ES6 class, which OCaml's class system doesn't map cleanly to.

**Solution**: Use a JavaScript shim file that extends WorkerEntrypoint, bridging the gap between functional OCaml and class-based JavaScript:

```javascript
// worker_entrypoint_shim.js
import { WorkerEntrypoint } from 'cloudflare:workers';

export function makeWorkerEntrypoint(handlers) {
  return class extends WorkerEntrypoint {
    constructor(ctx, env) {
      super(ctx, env);
      this._handlers = handlers;
    }

    async fetch(request) {
      if (this._handlers.fetch) {
        return await this._handlers.fetch(request, this.env, this.ctx);
      }
      return await super.fetch(request);
    }

    // ... other handlers ...
  };
}
```

```ocaml
(* OCaml binding to the shim *)
module WorkerEntrypoint = struct
  type 'env t

  external make :
    ?fetch:('env fetch_handler) ->
    ?scheduled:('env scheduled_handler) ->
    (* ... other handlers ... *)
    unit ->
    'env t = "makeWorkerEntrypoint"
    [@@mel.module "./worker_entrypoint_shim.js"]
end

(* Usage *)
let default = WorkerEntrypoint.make ~fetch:handle_request ()
```

**Why This Works**:
- ✅ JavaScript shim handles class extension properly
- ✅ OCaml code remains functional and idiomatic
- ✅ Clean separation: JS does classes, OCaml does logic
- ✅ Type-safe through Melange's FFI
- ✅ Handlers object created with `[@@mel.obj]`

**Alternatives Considered**:
1. **OCaml classes**: Don't compile to ES6 `class extends` syntax
2. **`[%mel.raw]`**: Writing JavaScript in strings - worse than separate file
3. **Module functors**: Overly complex for this use case

**Key Insight**: Melange/BuckleScript's OCaml object system doesn't map to ES6 classes. Using a small JavaScript shim is the pragmatic, maintainable solution endorsed by the community.

## Next Steps

1. **Fix Current KV Implementation Issues**
   - Review `.mli` interface carefully
   - Ensure `.ml` implementation matches exactly
   - Build incrementally to verify each section works

2. **Complete Example 2: KV Storage**
   - Once KV module builds correctly
   - Test all API endpoints work as documented

3. **Implement D1 Module**
   - Start with interface first
   - Implement incrementally with frequent builds
   - Follow the lessons learned from KV

4. **Create Example 3: D1 Database**
   - Showcase SQL queries, prepared statements, batching

5. **Implement R2 Module**
   - Object storage bindings
   - Build incrementally

6. **Create Example 4: R2 Storage**
   - File upload/download examples
