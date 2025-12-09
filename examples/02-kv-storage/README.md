# Example 2: KV Storage

A Cloudflare Worker demonstrating Workers KV usage, written in OCaml with Melange.

## Features Demonstrated

- ✅ Reading from KV with metadata
- ✅ Writing to KV with TTL expiration
- ✅ Deleting KV entries
- ✅ Listing keys with pagination
- ✅ Storing and retrieving metadata
- ✅ Type-safe KV bindings

## Prerequisites

- [Node.js](https://nodejs.org/) (v18 or later)
- [Dune](https://dune.build/) (v3.16 or later)
- [OCaml](https://ocaml.org/) (v4.14 or later)
- [Melange](https://melange.re/) (v4.0 or later)
- [Wrangler](https://developers.cloudflare.com/workers/wrangler/) (v3.0 or later)
- A Cloudflare account with KV namespace

## Setup

1. **Create a KV namespace:**
   ```bash
   wrangler kv namespace create CACHE
   ```

   This will output a namespace ID. Copy it.

2. **Update wrangler.toml:**

   Replace `preview_id` in `wrangler.toml` with your namespace ID:
   ```toml
   [[kv_namespaces]]
   binding = "CACHE"
   id = "your-namespace-id-here"
   ```

3. **Install dependencies:**
   ```bash
   npm install
   ```

4. **Build the worker:**
   ```bash
   npm run build
   ```

## Development

Run the worker locally:

```bash
npm run dev
```

Access at `http://localhost:8787`

## API Endpoints

### Get a Value

```bash
curl http://localhost:8787/cache/mykey
```

**Response:**
```json
{
  "key": "mykey",
  "value": "Hello, KV!",
  "metadata": {
    "created_at": 1704067200000,
    "type": "text"
  }
}
```

### Store a Value

```bash
curl -X PUT http://localhost:8787/cache/mykey \
  -H "Content-Type: application/json" \
  -d '{"value": "Hello, KV!", "ttl": 3600}'
```

**Request body:**
- `value` (required): The value to store
- `ttl` (optional): Time-to-live in seconds

**Response:**
```json
{
  "success": true,
  "key": "mykey",
  "ttl": 3600
}
```

### Delete a Value

```bash
curl -X DELETE http://localhost:8787/cache/mykey
```

**Response:**
```json
{
  "success": true,
  "key": "mykey"
}
```

### List All Keys

```bash
curl http://localhost:8787/cache
```

**Response:**
```json
{
  "keys": [
    {
      "name": "mykey",
      "metadata": {
        "created_at": 1704067200000,
        "type": "text"
      }
    }
  ],
  "count": 1,
  "list_complete": true,
  "cursor": null
}
```

## Deployment

Deploy to Cloudflare Workers:

```bash
npm run deploy
```

## Code Overview

The worker demonstrates KV operations using type-safe OCaml bindings:

```ocaml
(* Define environment with KV binding *)
type env = {
  cache : Kv.Namespace.t; [@mel.as "CACHE"]
} [@@deriving jsProperties]

(* Read with metadata *)
Js.Promise.(
  Namespace.get_with_metadata env.cache key
  |> then_ (function
      | Some {value; metadata} ->
          (* Use value and metadata *)
          resolve (...)
      | None ->
          (* Key not found *)
          resolve (...)
  )
)

(* Write with TTL *)
Js.Promise.(
  Namespace.put_with_options env.cache key value {
    expiration = None;
    expirationTtl = Some 3600;  (* 1 hour *)
    metadata = Some metadata_json;
  }
  |> then_ (fun () ->
      (* Value stored *)
      resolve (...)
  )
)

(* List keys *)
Js.Promise.(
  Namespace.list env.cache {
    limit = Some 100;
    prefix = None;
    cursor = None;
  }
  |> then_ (fun {keys; list_complete; cursor} ->
      (* Process keys *)
      resolve (...)
  )
)
```

## KV Characteristics

- **Eventual Consistency**: Writes propagate globally in ~60 seconds
- **Read Performance**: Optimized for high read volumes (millions/sec)
- **Value Size**: Up to 25 MB per value
- **Key Size**: Up to 512 bytes
- **Metadata Size**: Up to 1024 bytes (JSON-serialized)

## Learning Resources

- [Cloudflare Workers KV](https://developers.cloudflare.com/kv/)
- [KV API Reference](https://developers.cloudflare.com/kv/api/)
- [Melange Documentation](https://melange.re)

## License

MIT
