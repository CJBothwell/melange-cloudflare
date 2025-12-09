# Example 1: Basic Cloudflare Worker

A basic Cloudflare Worker written in OCaml using Melange, demonstrating core functionality of the `melange-cloudflare` bindings.

## Features Demonstrated

This example showcases:

- ✅ Request/Response handling
- ✅ URL routing and path matching
- ✅ Multiple content types (JSON, HTML, text)
- ✅ HTTP method handling (GET, POST, etc.)
- ✅ Custom headers and status codes
- ✅ Request inspection (headers, method, URL)
- ✅ HTTP redirects
- ✅ Request body parsing

## Prerequisites

- [Node.js](https://nodejs.org/) (v18 or later)
- [Dune](https://dune.build/) (v3.16 or later)
- [OCaml](https://ocaml.org/) (v4.14 or later)
- [Melange](https://melange.re/) (v4.0 or later)
- [Wrangler](https://developers.cloudflare.com/workers/wrangler/) (v3.0 or later)

## Setup

1. **Install Node dependencies:**
   ```bash
   npm install
   ```

2. **Build the worker:**
   ```bash
   npm run build
   ```

   This runs `dune build` which compiles the OCaml code to JavaScript using Melange.

## Development

Run the worker locally with Wrangler:

```bash
npm run dev
```

This starts a local development server. You can access the worker at `http://localhost:8787`.

## Available Endpoints

### JSON API Endpoints

- **`GET /api/hello`** - Returns a JSON greeting with timestamp
  ```bash
  curl http://localhost:8787/api/hello
  ```

- **`POST /api/echo`** - Echoes back the request body
  ```bash
  curl -X POST http://localhost:8787/api/echo -d "Hello, World!"
  ```

- **`GET /api/headers`** - Returns request headers as JSON
  ```bash
  curl http://localhost:8787/api/headers
  ```

- **`GET /api/methods`** - Shows HTTP method information
  ```bash
  curl http://localhost:8787/api/methods
  ```

### Other Endpoints

- **`GET /`** - Home page with interactive HTML documentation
- **`GET /redirect`** - Tests HTTP redirect (302 to example.com)
- **`GET /custom-headers`** - Response with custom headers

## Deployment

1. **Login to Cloudflare:**
   ```bash
   wrangler login
   ```

2. **Deploy to Cloudflare Workers:**
   ```bash
   npm run deploy
   ```

Your worker will be deployed to `https://melange-basic-worker.<your-subdomain>.workers.dev`

## Project Structure

```
01-basic-worker/
├── package.json       # Node.js dependencies and scripts
├── wrangler.toml      # Cloudflare Workers configuration
├── dune               # Dune build configuration
├── worker.ml          # Main worker implementation (OCaml)
└── README.md          # This file
```

## Code Overview

The worker is implemented in `worker.ml` using the `melange-cloudflare` bindings:

```ocaml
open Cloudflare
open Workers

(* Define environment type *)
type env = unit

(* Main request handler *)
let handle_request (request : Request.t) (_env : env) (_ctx : ExecutionContext.t) =
  let url = Request.url request in
  (* Route based on URL... *)
  ...

(* Register the handler *)
let () = FetchEvent.on_fetch handle_request
```

### Key Concepts

1. **Type-safe Request/Response**: Using OCaml's type system with Cloudflare Workers API
2. **Pattern matching for routing**: OCaml's pattern matching for clean URL routing
3. **Promise handling**: Using `Js.Promise` for async operations
4. **JSON handling**: Using `Js.Json` for type-safe JSON creation

## Learning Resources

- [Melange Documentation](https://melange.re)
- [Cloudflare Workers Documentation](https://developers.cloudflare.com/workers)
- [OCaml Documentation](https://ocaml.org/docs)

## Next Steps

After exploring this basic example, check out:

- **Example 2: KV Storage** - Learn how to use Cloudflare KV for key-value storage
- **Example 3: D1 Database** - Work with serverless SQL databases
- **Example 4: R2 Storage** - Handle object storage and file uploads

## License

MIT
