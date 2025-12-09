# Example 3: WorkerEntrypoint (RPC Service Bindings)

This example demonstrates how to use Cloudflare's `WorkerEntrypoint` class with Melange OCaml bindings. WorkerEntrypoint enables RPC (Remote Procedure Call) functionality, allowing Workers to communicate with each other via service bindings.

## What is WorkerEntrypoint?

`WorkerEntrypoint` is a class-based API for Cloudflare Workers that:

- Extends the standard Workers runtime with RPC capabilities
- Allows Workers to expose methods that other Workers can call
- Provides a structured way to handle multiple event types
- Enables service-to-service communication with type safety

## When to Use WorkerEntrypoint vs Handler

**Use `WorkerEntrypoint` when:**
- You need RPC functionality (service bindings)
- Your Worker will be called by other Workers
- You want to expose custom methods beyond standard handlers
- You're building a service-oriented architecture

**Use `Handler.make` when:**
- You only need basic HTTP request handling
- You prefer a simple object export pattern
- You don't need RPC functionality
- You want minimal boilerplate

## Implementation

This example shows a Worker using `WorkerEntrypoint` to handle HTTP requests. The same pattern can be extended to expose RPC methods.

### Key Features Demonstrated

1. **WorkerEntrypoint class usage**: Shows how the JavaScript shim creates a proper ES6 class
2. **Handler delegation**: OCaml functions are called from the class methods
3. **Type safety**: Full type checking for request/response handling
4. **Environment access**: Shows how `env` and `ctx` are available in handlers

## Files

- `src/index.ml` - Main Worker code using WorkerEntrypoint
- `src/dune` - Build configuration
- `wrangler.toml` - Cloudflare Worker configuration

## How It Works

1. **OCaml Handler**: You write functional OCaml code:
   ```ocaml
   let fetch_handler request env ctx =
     Response.make_json (Js.Json.string "Hello!")
     |> Js.Promise.resolve
   ```

2. **WorkerEntrypoint.make**: Wraps your handlers:
   ```ocaml
   let default = WorkerEntrypoint.make ~fetch:fetch_handler ()
   ```

3. **JavaScript Shim**: Generates ES6 class:
   ```javascript
   export default class extends WorkerEntrypoint {
     async fetch(request, env, ctx) {
       return fetch_handler(request, env, ctx);
     }
   }
   ```

4. **Cloudflare**: Runs your Worker with full RPC support!

## Running the Example

```bash
# Install dependencies
npm install

# Build the Worker
npm run build

# Deploy to Cloudflare
npm run deploy

# Or run locally for testing
npm run dev
```

## Extending with RPC Methods

To add custom RPC methods that other Workers can call:

```ocaml
(* Define your RPC methods *)
let get_user_data user_id env =
  (* Query database, process data *)
  Js.Promise.resolve (Js.Json.string "user data")

(* Export both HTTP handler and RPC methods *)
let default = WorkerEntrypoint.make ~fetch:fetch_handler ()

(* Note: Custom RPC method support coming soon! *)
```

## Learn More

- [Cloudflare WorkerEntrypoint Docs](https://developers.cloudflare.com/workers/runtime-apis/bindings/service-bindings/rpc/)
- [Service Bindings](https://developers.cloudflare.com/workers/runtime-apis/bindings/service-bindings/)
- [RPC Overview](https://developers.cloudflare.com/workers/runtime-apis/rpc/)
